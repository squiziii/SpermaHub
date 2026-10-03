-- синглтон: не даём запустить вторую копию (частая причина «старого худа» и пустых окон)
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

local KeySystem = {
    --// Конфигурация
    Config = {
        AdminPassword = "1337",        -- Пароль от админки
        MaxAttempts = 3,               -- Попыток до кика
        SaveKeys = true,               -- Сохранять ключи в файл
        KeysFile = "sperma_keys.json", -- Файл с ключами
        HwidLock = true,               -- HWID-привязка: ключ работает только на устройстве первой активации
        MetaFile = "sperma_meta.json",       -- пароль админки + чёрный список HWID + лог активаций
        HeartbeatFile = "sperma_heartbeat.json", -- метки «сейчас в игре» (key → unixtime)
        Debug = false,
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
    }
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local CoreGuiSvc = game:GetService("CoreGui")

--// HWID устройства (gethwid → fallback UserId)
local function GetHWID()
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
local function ksPrint(msg)
    if KeySystem.Config.Debug then
        print("[SpermaHub Key] " .. msg)
    end
end

local function ksNotify(title, msg, duration)
    if toastImpl then
        pcall(toastImpl, title, msg)
    else
        print(("[SpermaHub] %s: %s"):format(title, msg))
    end
end

--// Генерация случайного ключа
local function GenerateKeyString(length)
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
            hwidBlacklist = self.State.HwidBlacklist,
            log = self.State.ActLog,
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
            KeySystem:WriteHeartbeat(key)
        end
    end)
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
function KeySystem:GenerateKey(keyTypeIndex, customKey, noHwid)
    local keyType = self.KeyTypes[keyTypeIndex]
    if not keyType then return nil end

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

    self.State.KeysDB[newKey] = {
        type = keyType.Name,
        typeIndex = keyTypeIndex,
        created = now,
        expires = keyType.Duration == math.huge and math.huge or (now + keyType.Duration),
        used = false,
        generatedBy = "admin",
        hwid = nil,          -- свободен; при первом входе привяжется к устройству
        activations = 0,     -- счётчик успешных входов
        banned = false,      -- 🚫 бан (не впускает, но не удалён)
        noHwid = noHwid and true or false, -- VIP: без привязки к устройству
        note = nil,          -- заметка админа (ник покупателя)
        maxActivations = nil,-- лимит входов (nil = без лимита)
    }

    self:SaveKeys()
    ksPrint("Generated " .. keyType.Name .. " key: " .. newKey)

    return newKey, keyType
end

--// Проверка ключа
function KeySystem:ValidateKey(key)
    key = string.gsub(tostring(key), "%s+", "") -- Чистим пробелы

    --// Админ-пароль (чёрный список админа не блокируем)
    if key == self.Config.AdminPassword then
        self.State.IsAdmin = true
        self.State.Authenticated = true
        ksPrint("Admin access granted")
        return true, "admin"
    end

    local myHwid = GetHWID()

    --// 🚫 ЧЁРНЫЙ СПИСОК устройств: не впускаем вообще, даже с верным ключом
    if self.State.HwidBlacklist[myHwid] then
        ksNotify("Key System", "🚫 Ваше устройство в чёрном списке!", 3)
        self:LogEvent(key, myHwid, false, "blacklisted")
        return false, "blacklisted"
    end

    --// Проверка в базе
    local keyData = self.State.KeysDB[key]
    if keyData then
        local now = tick()

        --// Бан (заморозка без удаления)
        if keyData.banned then
            ksNotify("Key System", "🚫 Ключ заблокирован администратором!", 3)
            self:LogEvent(key, myHwid, false, "banned")
            return false, "banned"
        end

        -- Проверка срока
        if now > keyData.expires then
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
        self:StartHeartbeat(key) -- «сейчас в игре»

        self.State.Authenticated = true
        self.State.CurrentKey = key
        self.State.KeyType = keyData.type
        ksPrint("Key accepted: " .. keyData.type)
        return true, keyData.type
    end

    --// Неверный ключ
    self:LogEvent(key, myHwid, false, "invalid")
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
        if now > data.expires then
            self.State.KeysDB[key] = nil
            removed = removed + 1
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
            if keyType == "admin" then
                Status.Text = "✓ Admin access!"
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

                -- Запуск основного скрипта (если оформлен как функция)
                if _G.SpermaHubMain then
                    pcall(_G.SpermaHubMain)
                end
            end
        else
            Status.Text = "✗ Неверный ключ!"
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
    Main.Size = UDim2.new(0, 560, 0, 600)
    Main.Position = UDim2.new(0.5, -280, 0.5, -300)
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

    --// Поле СВОЕГО ключа (если пусто — случайный)
    local CustomKeyOutline = Instance.new("Frame")
    CustomKeyOutline.Size = UDim2.new(1, -20, 0, 30)
    CustomKeyOutline.Position = UDim2.new(0, 10, 0, 162)
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
    GenBtn.Position = UDim2.new(0, 10, 0, 198)
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
    ResultBox.Position = UDim2.new(0, 10, 0, 236)
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
    CopyBtn.Position = UDim2.new(0, 10, 0, 272)
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

    --// Stats
    local StatsLabel = Instance.new("TextLabel")
    StatsLabel.Size = UDim2.new(1, -20, 0, 16)
    StatsLabel.Position = UDim2.new(0, 10, 1, -40)
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
    HwidLabel.Position = UDim2.new(0, 10, 1, -24)
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
    KeysScroll.Size = UDim2.new(1, -20, 1, -330)
    KeysScroll.Position = UDim2.new(0, 10, 0, 68)
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

    --// rev31: РЕДАКТОР избранного ключа
    local Editor = Instance.new("Frame")
    Editor.Size = UDim2.new(1, -20, 0, 120)
    Editor.Position = UDim2.new(0, 10, 1, -256)
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
    local BanBtn  = mkEdBtn("🚫 БАН",  0, 6,   0, 84, 50, Color3.fromRGB(170, 60, 60))
    local ExtBtn  = mkEdBtn("+24 часа",0, 96,  0, 84, 50, Color3.fromRGB(100, 149, 237))
    local LimBtn  = mkEdBtn("Лимит: ∞",0, 186, 0, 80, 50, Color3.fromRGB(120, 90, 160))
    local VipBtn  = mkEdBtn("HWID: —", 0, 6,   0, 84, 78, Color3.fromRGB(90, 90, 110))
    local TypBtn  = mkEdBtn("Тип:",    0, 96,  0, 84, 78, Color3.fromRGB(90, 90, 110))
    local BLBtn   = mkEdBtn("BL —",    0, 186, 0, 80, 78, Color3.fromRGB(150, 60, 90))

    local EdHint = Instance.new("TextLabel")
    EdHint.Size = UDim2.new(1, -16, 0, 10)
    EdHint.Position = UDim2.new(0, 8, 0, 106)
    EdHint.BackgroundTransparency = 1
    EdHint.Text = "Лимит = число входов; Тип↻ меняет срок от сейчас; BL = чёрный список устройства"
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
            BanBtn.Text = "🚫 БАН"; LimBtn.Text = "Лимит: ∞"
            VipBtn.Text = "HWID: —"; TypBtn.Text = "Тип:"; BLBtn.Text = "BL —"
            NoteBox.Text = ""
            lastSyncSel = nil
            return
        end
        SelLabel.Text = "Выбран: " .. k
        if lastSyncSel ~= k then
            NoteBox.Text = d.note or ""
            lastSyncSel = k
        end
        BanBtn.Text = d.banned and "✅ РАЗБАН" or "🚫 БАН"
        LimBtn.Text = "Лимит: " .. (d.maxActivations and tostring(d.maxActivations) or "∞")
        VipBtn.Text = d.noHwid and "HWID: ВЫКЛ" or "HWID: ВКЛ"
        TypBtn.Text = "Тип: " .. tostring(d.type)
        local blOk = d.hwid and KeySystem.State.HwidBlacklist[tostring(d.hwid)]
        BLBtn.Text = blOk and "BL ✓ (снять)" or "BL +"
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

    --// rev31: ЛОГ АКТИВАЦИЙ
    local LogPanel = Instance.new("Frame")
    LogPanel.Size = UDim2.new(1, -20, 0, 120)
    LogPanel.Position = UDim2.new(0, 10, 1, -130)
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
        local active = 0
        local expired = 0
        local now = tick()

        for _, data in pairs(KeySystem.State.KeysDB) do
            if now > data.expires then
                expired = expired + 1
            else
                active = active + 1
            end
        end

        StatsLabel.Text = string.format("Всего: %d | Актив: %d | Истёкло: %d", total, active, expired)
    end

    RefreshKeysList = function()
        for _, child in ipairs(KeysScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local now = tick()
        KeySystem:ReadHeartbeats()
        local filter = keysFilter or "all"

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
            local isExpired = now > data.expires

            local show = (filter == "all")
                or (filter == "active" and not isExpired)
                or (filter == "expired" and isExpired)
                or (filter == "free" and data.hwid == nil)
            if show then
                local online = KeySystem:IsOnline(key)
                local kt = KeySystem.KeyTypes[data.typeIndex]
                local keyColor = data.banned and Color3.fromRGB(255, 80, 80)
                    or (isExpired and Color3.fromRGB(100, 100, 100)
                    or (kt and kt.Color or Color3.fromRGB(255, 215, 0)))
                local isSel = (KeySystem.State.SelectedKey == key)

                local KeyFrame = Instance.new("Frame")
                KeyFrame.Size = UDim2.new(1, -10, 0, 50)
                KeyFrame.BackgroundColor3 = isSel and Color3.fromRGB(45, 45, 70) or Color3.fromRGB(25, 25, 40)
                KeyFrame.BorderSizePixel = 0
                KeyFrame.Parent = KeysScroll

                local KF_Corner = Instance.new("UICorner")
                KF_Corner.CornerRadius = UDim.new(0, 4)
                KF_Corner.Parent = KeyFrame

                -- невидимая кнопка выбора (левее кнопок удаления)
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

                local KeyLabel = Instance.new("TextLabel")
                KeyLabel.Size = UDim2.new(1, -70, 0, 20)
                KeyLabel.Position = UDim2.new(0, 8, 0, 5)
                KeyLabel.BackgroundTransparency = 1
                KeyLabel.Text = (online and "🟢 " or "") .. key .. (data.note and (" — " .. data.note) or "")
                KeyLabel.TextColor3 = keyColor
                KeyLabel.Font = Enum.Font.GothamBold
                KeyLabel.TextSize = 11
                KeyLabel.TextXAlignment = Enum.TextXAlignment.Left
                KeyLabel.TextTruncate = Enum.TextTruncate.AtEnd
                KeyLabel.Parent = KeyFrame

                local InfoLabel = Instance.new("TextLabel")
                InfoLabel.Size = UDim2.new(1, -70, 0, 15)
                InfoLabel.Position = UDim2.new(0, 8, 0, 25)
                InfoLabel.BackgroundTransparency = 1

                local timeLeft = ""
                if isExpired then
                    timeLeft = "ИСТЁК"
                elseif data.expires == math.huge then
                    timeLeft = "Навсегда"
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
                    RefreshKeysList()
                end)
            end
        end

        if SyncEditor then pcall(SyncEditor) end
        UpdateStats()
    end

    --// rev31: ЛЕВАЯ ПАНЕЛЬ — мультиген / VIP / пароль / экспорт-импорт / вайп
    local genNoHwid = false

    local NOutline = Instance.new("Frame")
    NOutline.Size = UDim2.new(0, 72, 0, 26)
    NOutline.Position = UDim2.new(0, 10, 0, 308)
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
    NoHwidBtn.Position = UDim2.new(0, 87, 0, 308)
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
    PassHint.Position = UDim2.new(0, 10, 0, 342)
    PassHint.BackgroundTransparency = 1
    PassHint.Text = "Новый пароль админки (≥2 символа):"
    PassHint.TextColor3 = Color3.fromRGB(150, 150, 170)
    PassHint.Font = Enum.Font.Gotham
    PassHint.TextSize = 10
    PassHint.TextXAlignment = Enum.TextXAlignment.Left
    PassHint.Parent = LeftPanel

    local PassOutline = Instance.new("Frame")
    PassOutline.Size = UDim2.new(1, -116, 0, 26)
    PassOutline.Position = UDim2.new(0, 10, 0, 356)
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
    PassSaveBtn.Position = UDim2.new(1, -106, 0, 356)
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
    ExpBtn.Position = UDim2.new(0, 10, 0, 388)
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
    ImpBtn.Position = UDim2.new(0.5, 5, 0, 388)
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
    ImpOutline.Position = UDim2.new(0, 10, 0, 420)
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

    --// вайп базы (двойное нажатие)
    local WipeBtn = Instance.new("TextButton")
    WipeBtn.Size = UDim2.new(1, -20, 0, 24)
    WipeBtn.Position = UDim2.new(0, 10, 0, 452)
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
        lastGenList = {}
        local lastErr = nil
        for i = 1, n do
            local newKey, keyType, err = KeySystem:GenerateKey(selectedType, (i == 1 and hasCustom) and custom or nil, genNoHwid)
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
        ScreenGui:Destroy()
        -- панель закрыта → ВОТ ТЕПЕРЬ грузим основной скрипт
        KeySystem.State.AdminDone = true
    end)

    --// Init
    RefreshKeysList()
    SyncEditor()
    RefreshLog()

    return ScreenGui
end

--// Инициализация
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

    self:CreateUserGUI()
end

--// Запуск
KeySystem:Init()

--// Ожидание авторизации.
-- АДМИНКА НЕ ГРУЗИТ скрипт сразу: основной скрипт стартует,
-- когда админ закроет панель (×); «Закрыть скрипт» в админке убивает всё.
repeat task.wait(0.1) until
    (KeySystem.State.Authenticated and not KeySystem.State.IsAdmin)
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
print("[SpermaHub] сборка: build18 rev31 (АДМИНКА ХАРДКОР: бан, блэклист HWID, заметки, лимит входов, VIP без привязки, продление, смена типа, лог, мультиген, экспорт/импорт, вайп, смена пароля, 🟢-онлайн)")

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
-- boot-плашка живёт максимум 15 сек: если скрипт упадёт/повиснет — она не останется "старым худом"
task.delay(15, function() pcall(function() BootGui:Destroy() end) end)

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
    "SpermaHubFlingTarget","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL","SpermaHubNLToggle","SpermaHubClickGui",
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
        SpermaKeySystem = true, SpermaAdmin = true, SpermaHubToast = true, SpermaHubBoot = true, SpermaHubErrToast = true, SpermaLinoria = true, Rayfield = true, KeyUI = true,
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
-- ВСТРОЕННЫЙ Rayfield (Beta 8, открытый код: jensonhirst/Rayfield/source)
-- 113 KB, сеть НЕ нужна; сетевые зеркала — только фолбэк. WindUI уничтожен.
-- =====================================================================
local RAYFIELD_SRC = [=[
--[[

Rayfield Interface Suite
by Sirius

shlex | Designing + Programming
iRay  | Programming

]]



local Release = "Beta 8"
local NotificationDuration = 6.5
local RayfieldFolder = "Rayfield"
local ConfigurationFolder = RayfieldFolder.."/Configurations"
local ConfigurationExtension = ".rfld"



local RayfieldLibrary = {
	Flags = {},
	Theme = {
		Default = {
			TextFont = "Default", -- Default will use the various font faces used across Rayfield
			TextColor = Color3.fromRGB(240, 240, 240),

			Background = Color3.fromRGB(25, 25, 25),
			Topbar = Color3.fromRGB(34, 34, 34),
			Shadow = Color3.fromRGB(20, 20, 20),

			NotificationBackground = Color3.fromRGB(20, 20, 20),
			NotificationActionsBackground = Color3.fromRGB(230, 230, 230),

			TabBackground = Color3.fromRGB(80, 80, 80),
			TabStroke = Color3.fromRGB(85, 85, 85),
			TabBackgroundSelected = Color3.fromRGB(210, 210, 210),
			TabTextColor = Color3.fromRGB(240, 240, 240),
			SelectedTabTextColor = Color3.fromRGB(50, 50, 50),

			ElementBackground = Color3.fromRGB(35, 35, 35),
			ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
			SecondaryElementBackground = Color3.fromRGB(25, 25, 25), -- For labels and paragraphs
			ElementStroke = Color3.fromRGB(50, 50, 50),
			SecondaryElementStroke = Color3.fromRGB(40, 40, 40), -- For labels and paragraphs

			SliderBackground = Color3.fromRGB(43, 105, 159),
			SliderProgress = Color3.fromRGB(43, 105, 159),
			SliderStroke = Color3.fromRGB(48, 119, 177),

			ToggleBackground = Color3.fromRGB(30, 30, 30),
			ToggleEnabled = Color3.fromRGB(0, 146, 214),
			ToggleDisabled = Color3.fromRGB(100, 100, 100),
			ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
			ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
			ToggleDisabledOuterStroke = Color3.fromRGB(65, 65, 65),

			InputBackground = Color3.fromRGB(30, 30, 30),
			InputStroke = Color3.fromRGB(65, 65, 65),
			PlaceholderColor = Color3.fromRGB(178, 178, 178)
		},
		Light = {
			TextFont = "Gotham", -- Default will use the various font faces used across Rayfield
			TextColor = Color3.fromRGB(50, 50, 50), -- i need to make all text 240, 240, 240 and base gray on transparency not color to do this

			Background = Color3.fromRGB(255, 255, 255),
			Topbar = Color3.fromRGB(217, 217, 217),
			Shadow = Color3.fromRGB(223, 223, 223),

			NotificationBackground = Color3.fromRGB(20, 20, 20),
			NotificationActionsBackground = Color3.fromRGB(230, 230, 230),

			TabBackground = Color3.fromRGB(220, 220, 220),
			TabStroke = Color3.fromRGB(112, 112, 112),
			TabBackgroundSelected = Color3.fromRGB(0, 142, 208),
			TabTextColor = Color3.fromRGB(240, 240, 240),
			SelectedTabTextColor = Color3.fromRGB(50, 50, 50),

			ElementBackground = Color3.fromRGB(198, 198, 198),
			ElementBackgroundHover = Color3.fromRGB(230, 230, 230),
			SecondaryElementBackground = Color3.fromRGB(136, 136, 136), -- For labels and paragraphs
			ElementStroke = Color3.fromRGB(180, 199, 97),
			SecondaryElementStroke = Color3.fromRGB(40, 40, 40), -- For labels and paragraphs

			SliderBackground = Color3.fromRGB(31, 159, 71),
			SliderProgress = Color3.fromRGB(31, 159, 71),
			SliderStroke = Color3.fromRGB(42, 216, 94),

			ToggleBackground = Color3.fromRGB(170, 203, 60),
			ToggleEnabled = Color3.fromRGB(32, 214, 29),
			ToggleDisabled = Color3.fromRGB(100, 22, 23),
			ToggleEnabledStroke = Color3.fromRGB(17, 255, 0),
			ToggleDisabledStroke = Color3.fromRGB(65, 8, 8),
			ToggleEnabledOuterStroke = Color3.fromRGB(0, 170, 0),
			ToggleDisabledOuterStroke = Color3.fromRGB(170, 0, 0),

			InputBackground = Color3.fromRGB(31, 159, 71),
			InputStroke = Color3.fromRGB(19, 65, 31),
			PlaceholderColor = Color3.fromRGB(178, 178, 178)
		}
	}
}



-- Services

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- Interface Management
local Rayfield = game:GetObjects("rbxassetid://10804731440")[1]

Rayfield.Enabled = false


if gethui then
	Rayfield.Parent = gethui()
elseif syn and syn.protect_gui then 
	syn.protect_gui(Rayfield)
	Rayfield.Parent = CoreGui
elseif CoreGui:FindFirstChild("RobloxGui") then
	Rayfield.Parent = CoreGui:FindFirstChild("RobloxGui")
else
	Rayfield.Parent = CoreGui
end

if gethui then
	for _, Interface in ipairs(gethui():GetChildren()) do
		if Interface.Name == Rayfield.Name and Interface ~= Rayfield then
			Interface.Enabled = false
			Interface.Name = "Rayfield-Old"
		end
	end
else
	for _, Interface in ipairs(CoreGui:GetChildren()) do
		if Interface.Name == Rayfield.Name and Interface ~= Rayfield then
			Interface.Enabled = false
			Interface.Name = "Rayfield-Old"
		end
	end
end

-- Object Variables

local Camera = workspace.CurrentCamera
local Main = Rayfield.Main
local Topbar = Main.Topbar
local Elements = Main.Elements
local LoadingFrame = Main.LoadingFrame
local TabList = Main.TabList

Rayfield.DisplayOrder = 100
LoadingFrame.Version.Text = Release


-- Variables

local request = (syn and syn.request) or (http and http.request) or http_request
local CFileName = nil
local CEnabled = false
local Minimised = false
local Hidden = false
local Debounce = false
local Notifications = Rayfield.Notifications

local SelectedTheme = RayfieldLibrary.Theme.Default

function ChangeTheme(ThemeName)
	SelectedTheme = RayfieldLibrary.Theme[ThemeName]
	for _, obj in ipairs(Rayfield:GetDescendants()) do
		if obj.ClassName == "TextLabel" or obj.ClassName == "TextBox" or obj.ClassName == "TextButton" then
			if SelectedTheme.TextFont ~= "Default" then 
				obj.TextColor3 = SelectedTheme.TextColor
				obj.Font = SelectedTheme.TextFont
			end
		end
	end

	Rayfield.Main.BackgroundColor3 = SelectedTheme.Background
	Rayfield.Main.Topbar.BackgroundColor3 = SelectedTheme.Topbar
	Rayfield.Main.Topbar.CornerRepair.BackgroundColor3 = SelectedTheme.Topbar
	Rayfield.Main.Shadow.Image.ImageColor3 = SelectedTheme.Shadow

	Rayfield.Main.Topbar.ChangeSize.ImageColor3 = SelectedTheme.TextColor
	Rayfield.Main.Topbar.Hide.ImageColor3 = SelectedTheme.TextColor
	Rayfield.Main.Topbar.Theme.ImageColor3 = SelectedTheme.TextColor

	for _, TabPage in ipairs(Elements:GetChildren()) do
		for _, Element in ipairs(TabPage:GetChildren()) do
			if Element.ClassName == "Frame" and Element.Name ~= "Placeholder" and Element.Name ~= "SectionSpacing" and Element.Name ~= "SectionTitle"  then
				Element.BackgroundColor3 = SelectedTheme.ElementBackground
				Element.UIStroke.Color = SelectedTheme.ElementStroke
			end
		end
	end

end

local function AddDraggingFunctionality(DragPoint, Main)
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false
		DragPoint.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				Dragging = true
				MousePos = Input.Position
				FramePos = Main.Position

				Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then
						Dragging = false
					end
				end)
			end
		end)
		DragPoint.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				DragInput = Input
			end
		end)
		UserInputService.InputChanged:Connect(function(Input)
			if Input == DragInput and Dragging then
				local Delta = Input.Position - MousePos
				TweenService:Create(Main, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position  = UDim2.new(FramePos.X.Scale,FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)}):Play()
			end
		end)
	end)
end   

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end    

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadConfiguration(Configuration)
	local Data = HttpService:JSONDecode(Configuration)
	for FlagName, FlagValue in next, Data do
		if RayfieldLibrary.Flags[FlagName] then
			spawn(function() 
				if RayfieldLibrary.Flags[FlagName].Type == "ColorPicker" then
					RayfieldLibrary.Flags[FlagName]:Set(UnpackColor(FlagValue))
				else
					if RayfieldLibrary.Flags[FlagName].CurrentValue or RayfieldLibrary.Flags[FlagName].CurrentKeybind or RayfieldLibrary.Flags[FlagName].CurrentOption or RayfieldLibrary.Flags[FlagName].Color ~= FlagValue then RayfieldLibrary.Flags[FlagName]:Set(FlagValue) end
				end    
			end)
		else
			RayfieldLibrary:Notify({Title = "Flag Error", Content = "Rayfield was unable to find '"..FlagName.. "'' in the current script"})
		end
	end
end

local function SaveConfiguration()
	if not CEnabled then return end
	local Data = {}
	for i,v in pairs(RayfieldLibrary.Flags) do
		if v.Type == "ColorPicker" then
			Data[i] = PackColor(v.Color)
		else
			Data[i] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
		end
	end	
	writefile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension, tostring(HttpService:JSONEncode(Data)))
end

local neon = (function() -- Open sourced neon module
	local module = {}

	do
		local function IsNotNaN(x)
			return x == x
		end
		local continued = IsNotNaN(Camera:ScreenPointToRay(0,0).Origin.x)
		while not continued do
			RunService.RenderStepped:wait()
			continued = IsNotNaN(Camera:ScreenPointToRay(0,0).Origin.x)
		end
	end
	local RootParent = Camera
	if getgenv().SecureMode == nil then
		RootParent = Camera
	else
		if not getgenv().SecureMode then
			RootParent = Camera
		else 
			RootParent = nil
		end
	end


	local binds = {}
	local root = Instance.new('Folder', RootParent)
	root.Name = 'neon'


	local GenUid; do
		local id = 0
		function GenUid()
			id = id + 1
			return 'neon::'..tostring(id)
		end
	end

	local DrawQuad; do
		local acos, max, pi, sqrt = math.acos, math.max, math.pi, math.sqrt
		local sz = 0.2

		function DrawTriangle(v1, v2, v3, p0, p1)
			local s1 = (v1 - v2).magnitude
			local s2 = (v2 - v3).magnitude
			local s3 = (v3 - v1).magnitude
			local smax = max(s1, s2, s3)
			local A, B, C
			if s1 == smax then
				A, B, C = v1, v2, v3
			elseif s2 == smax then
				A, B, C = v2, v3, v1
			elseif s3 == smax then
				A, B, C = v3, v1, v2
			end

			local para = ( (B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z ) / (A-B).magnitude
			local perp = sqrt((C-A).magnitude^2 - para*para)
			local dif_para = (A - B).magnitude - para

			local st = CFrame.new(B, A)
			local za = CFrame.Angles(pi/2,0,0)

			local cf0 = st

			local Top_Look = (cf0 * za).lookVector
			local Mid_Point = A + CFrame.new(A, B).LookVector * para
			local Needed_Look = CFrame.new(Mid_Point, C).LookVector
			local dot = Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z

			local ac = CFrame.Angles(0, 0, acos(dot))

			cf0 = cf0 * ac
			if ((cf0 * za).lookVector - Needed_Look).magnitude > 0.01 then
				cf0 = cf0 * CFrame.Angles(0, 0, -2*acos(dot))
			end
			cf0 = cf0 * CFrame.new(0, perp/2, -(dif_para + para/2))

			local cf1 = st * ac * CFrame.Angles(0, pi, 0)
			if ((cf1 * za).lookVector - Needed_Look).magnitude > 0.01 then
				cf1 = cf1 * CFrame.Angles(0, 0, 2*acos(dot))
			end
			cf1 = cf1 * CFrame.new(0, perp/2, dif_para/2)

			if not p0 then
				p0 = Instance.new('Part')
				p0.FormFactor = 'Custom'
				p0.TopSurface = 0
				p0.BottomSurface = 0
				p0.Anchored = true
				p0.CanCollide = false
				p0.Material = 'Glass'
				p0.Size = Vector3.new(sz, sz, sz)
				local mesh = Instance.new('SpecialMesh', p0)
				mesh.MeshType = 2
				mesh.Name = 'WedgeMesh'
			end
			p0.WedgeMesh.Scale = Vector3.new(0, perp/sz, para/sz)
			p0.CFrame = cf0

			if not p1 then
				p1 = p0:clone()
			end
			p1.WedgeMesh.Scale = Vector3.new(0, perp/sz, dif_para/sz)
			p1.CFrame = cf1

			return p0, p1
		end

		function DrawQuad(v1, v2, v3, v4, parts)
			parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
			parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
		end
	end

	function module:BindFrame(frame, properties)
		if RootParent == nil then return end
		if binds[frame] then
			return binds[frame].parts
		end

		local uid = "SpermaRayPulse"
		local parts = {}
		local f = Instance.new('Folder', root)
		f.Name = frame.Name

		local parents = {}
		do
			local function add(child)
				if child:IsA'GuiObject' then
					parents[#parents + 1] = child
					add(child.Parent)
				end
			end
			add(frame)
		end

		local function UpdateOrientation(fetchProps)
			local zIndex = 1 - 0.05*frame.ZIndex
			local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
			local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
			do
				local rot = 0;
				for _, v in ipairs(parents) do
					rot = rot + v.Rotation
				end
				if rot ~= 0 and rot%180 ~= 0 then
					local mid = tl:lerp(br, 0.5)
					local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
					local vec = tl
					tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
					tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
					bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
					br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
				end
			end
			DrawQuad(
				Camera:ScreenPointToRay(tl.x, tl.y, zIndex).Origin, 
				Camera:ScreenPointToRay(tr.x, tr.y, zIndex).Origin, 
				Camera:ScreenPointToRay(bl.x, bl.y, zIndex).Origin, 
				Camera:ScreenPointToRay(br.x, br.y, zIndex).Origin, 
				parts
			)
			if fetchProps then
				for _, pt in pairs(parts) do
					pt.Parent = f
				end
				for propName, propValue in pairs(properties) do
					for _, pt in pairs(parts) do
						pt[propName] = propValue
					end
				end
			end
		end

		UpdateOrientation(true)
		RunService:BindToRenderStep(uid, 2000, UpdateOrientation)

		binds[frame] = {
			uid = uid;
			parts = parts;
		}
		return binds[frame].parts
	end

	function module:Modify(frame, properties)
		local parts = module:GetBoundParts(frame)
		if parts then
			for propName, propValue in pairs(properties) do
				for _, pt in pairs(parts) do
					pt[propName] = propValue
				end
			end
		end
	end

	function module:UnbindFrame(frame)
		if RootParent == nil then return end
		local cb = binds[frame]
		if cb then
			RunService:UnbindFromRenderStep(cb.uid)
			for _, v in pairs(cb.parts) do
				v:Destroy()
			end
			binds[frame] = nil
		end
	end

	function module:HasBinding(frame)
		return binds[frame] ~= nil
	end

	function module:GetBoundParts(frame)
		return binds[frame] and binds[frame].parts
	end


	return module

end)()

function RayfieldLibrary:Notify(NotificationSettings)
	spawn(function()
		local ActionCompleted = true
		local Notification = Notifications.Template:Clone()
		Notification.Parent = Notifications
		Notification.Name = NotificationSettings.Title or "Unknown Title"
		Notification.Visible = true

		local blurlight = nil
		if not getgenv().SecureMode then
			blurlight = Instance.new("DepthOfFieldEffect",game:GetService("Lighting"))
			blurlight.Enabled = true
			blurlight.FarIntensity = 0
			blurlight.FocusDistance = 51.6
			blurlight.InFocusRadius = 50
			blurlight.NearIntensity = 1
			game:GetService("Debris"):AddItem(script,0)
		end

		Notification.Actions.Template.Visible = false

		if NotificationSettings.Actions then
			for _, Action in pairs(NotificationSettings.Actions) do
				ActionCompleted = false
				local NewAction = Notification.Actions.Template:Clone()
				NewAction.BackgroundColor3 = SelectedTheme.NotificationActionsBackground
				if SelectedTheme ~= RayfieldLibrary.Theme.Default then
					NewAction.TextColor3 = SelectedTheme.TextColor
				end
				NewAction.Name = Action.Name
				NewAction.Visible = true
				NewAction.Parent = Notification.Actions
				NewAction.Text = Action.Name
				NewAction.BackgroundTransparency = 1
				NewAction.TextTransparency = 1
				NewAction.Size = UDim2.new(0, NewAction.TextBounds.X + 27, 0, 36)

				NewAction.MouseButton1Click:Connect(function()
					local Success, Response = pcall(Action.Callback)
					if not Success then
						print("Rayfield | Action: "..Action.Name.." Callback Error " ..tostring(Response))
					end
					ActionCompleted = true
				end)
			end
		end
		Notification.BackgroundColor3 = SelectedTheme.Background
		Notification.Title.Text = NotificationSettings.Title or "Unknown"
		Notification.Title.TextTransparency = 1
		Notification.Title.TextColor3 = SelectedTheme.TextColor
		Notification.Description.Text = NotificationSettings.Content or "Unknown"
		Notification.Description.TextTransparency = 1
		Notification.Description.TextColor3 = SelectedTheme.TextColor
		Notification.Icon.ImageColor3 = SelectedTheme.TextColor
		if NotificationSettings.Image then
			Notification.Icon.Image = "rbxassetid://"..tostring(NotificationSettings.Image) 
		else
			Notification.Icon.Image = "rbxassetid://3944680095"
		end

		Notification.Icon.ImageTransparency = 1

		Notification.Parent = Notifications
		Notification.Size = UDim2.new(0, 260, 0, 80)
		Notification.BackgroundTransparency = 1

		TweenService:Create(Notification, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 295, 0, 91)}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
		Notification:TweenPosition(UDim2.new(0.5,0,0.915,0),'Out','Quint',0.8,true)

		wait(0.3)
		TweenService:Create(Notification.Icon, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
		TweenService:Create(Notification.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
		wait(0.2)



		-- Requires Graphics Level 8-10
		if getgenv().SecureMode == nil then
			TweenService:Create(Notification, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.4}):Play()
		else
			if not getgenv().SecureMode then
				TweenService:Create(Notification, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.4}):Play()
			else 
				TweenService:Create(Notification, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			end
		end

		if Rayfield.Name == "Rayfield" then
			neon:BindFrame(Notification.BlurModule, {
				Transparency = 0.98;
				BrickColor = BrickColor.new("Institutional white");
			})
		end

		if not NotificationSettings.Actions then
			wait(NotificationSettings.Duration or NotificationDuration - 0.5)
		else
			wait(0.8)
			TweenService:Create(Notification, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 295, 0, 132)}):Play()
			wait(0.3)
			for _, Action in ipairs(Notification.Actions:GetChildren()) do
				if Action.ClassName == "TextButton" and Action.Name ~= "Template" then
					TweenService:Create(Action, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.2}):Play()
					TweenService:Create(Action, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
					wait(0.05)
				end
			end
		end

		repeat wait(0.001) until ActionCompleted

		for _, Action in ipairs(Notification.Actions:GetChildren()) do
			if Action.ClassName == "TextButton" and Action.Name ~= "Template" then
				TweenService:Create(Action, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				TweenService:Create(Action, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
			end
		end

		TweenService:Create(Notification.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0.47, 0,0.234, 0)}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(0.528, 0,0.637, 0)}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 280, 0, 83)}):Play()
		TweenService:Create(Notification.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()

		wait(0.3)
		TweenService:Create(Notification.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.4}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
		wait(0.4)
		TweenService:Create(Notification, TweenInfo.new(0.9, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 260, 0, 0)}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(Notification.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		wait(0.2)
		if not getgenv().SecureMode then
			neon:UnbindFrame(Notification.BlurModule)
			blurlight:Destroy()
		end
		wait(0.9)
		Notification:Destroy()
	end)
end

function Hide()
	Debounce = true
	RayfieldLibrary:Notify({Title = "Interface Hidden", Content = "The interface has been hidden, you can unhide the interface by tapping K", Duration = 7})
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 470, 0, 400)}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 470, 0, 45)}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar.CornerRepair, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
	TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
	for _, TopbarButton in ipairs(Topbar:GetChildren()) do
		if TopbarButton.ClassName == "ImageButton" then
			TweenService:Create(TopbarButton, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		end
	end
	for _, tabbtn in ipairs(TabList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
			TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
			TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
		end
	end
	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						if element.Name == "SectionTitle" then
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						else
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
								child.Visible = false
							end
						end
					end
				end
			end
		end
	end
	wait(0.5)
	Main.Visible = false
	Debounce = false
end

function Unhide()
	Debounce = true
	Main.Position = UDim2.new(0.5, 0, 0.5, 0)
	Main.Visible = true
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 475)}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 45)}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.4}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	if Minimised then
		spawn(Maximise)
	end
	for _, TopbarButton in ipairs(Topbar:GetChildren()) do
		if TopbarButton.ClassName == "ImageButton" then
			TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
		end
	end
	for _, tabbtn in ipairs(TabList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
				TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
				TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.9}):Play()
				TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
				TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
			else
				TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
				TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.2}):Play()
				TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
				TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			end

		end
	end
	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						if element.Name == "SectionTitle" then
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						else
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
								child.Visible = true
							end
						end
					end
				end
			end
		end
	end
	wait(0.5)
	Minimised = false
	Debounce = false
end

function Maximise()
	Debounce = true
	Topbar.ChangeSize.Image = "rbxassetid://"..10137941941


	TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.4}):Play()
	TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 475)}):Play()
	TweenService:Create(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 45)}):Play()
	TabList.Visible = true
	wait(0.2)

	Elements.Visible = true

	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						if element.Name == "SectionTitle" then
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						else
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
								child.Visible = true
							end
						end
					end
				end
			end
		end
	end


	wait(0.1)

	for _, tabbtn in ipairs(TabList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
				TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
				TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
				TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.9}):Play()
			else
				TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
				TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
				TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.2}):Play()
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
				TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			end

		end
	end


	wait(0.5)
	Debounce = false
end

function Minimise()
	Debounce = true
	Topbar.ChangeSize.Image = "rbxassetid://"..11036884234

	for _, tabbtn in ipairs(TabList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
			TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
			TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
		end
	end

	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						if element.Name == "SectionTitle" then
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						else
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
								child.Visible = false
							end
						end
					end
				end
			end
		end
	end

	TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
	TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 495, 0, 45)}):Play()
	TweenService:Create(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 495, 0, 45)}):Play()

	wait(0.3)

	Elements.Visible = false
	TabList.Visible = false

	wait(0.2)
	Debounce = false
end

function RayfieldLibrary:CreateWindow(Settings)
	local Passthrough = false
	Topbar.Title.Text = Settings.Name
	Main.Size = UDim2.new(0, 450, 0, 260)
	Main.Visible = true
	Main.BackgroundTransparency = 1
	LoadingFrame.Title.TextTransparency = 1
	LoadingFrame.Subtitle.TextTransparency = 1
	Main.Shadow.Image.ImageTransparency = 1
	LoadingFrame.Version.TextTransparency = 1
	LoadingFrame.Title.Text = Settings.LoadingTitle or "Rayfield Interface Suite"
	LoadingFrame.Subtitle.Text = Settings.LoadingSubtitle or "by Sirius"
	if Settings.LoadingTitle ~= "Rayfield Interface Suite" then
		LoadingFrame.Version.Text = "Rayfield UI"
	end
	Topbar.Visible = false
	Elements.Visible = false
	LoadingFrame.Visible = true


	pcall(function()
		if not Settings.ConfigurationSaving.FileName then
			Settings.ConfigurationSaving.FileName = tostring(game.PlaceId)
		end
		if not isfolder(RayfieldFolder.."/".."Configuration Folders") then

		end
		if Settings.ConfigurationSaving.Enabled == nil then
			Settings.ConfigurationSaving.Enabled = false
		end
		CFileName = Settings.ConfigurationSaving.FileName
		ConfigurationFolder = Settings.ConfigurationSaving.FolderName or ConfigurationFolder
		CEnabled = Settings.ConfigurationSaving.Enabled

		if Settings.ConfigurationSaving.Enabled then
			if not isfolder(ConfigurationFolder) then
				makefolder(ConfigurationFolder)
			end	
		end
	end)

	AddDraggingFunctionality(Topbar,Main)

	for _, TabButton in ipairs(TabList:GetChildren()) do
		if TabButton.ClassName == "Frame" and TabButton.Name ~= "Placeholder" then
			TabButton.BackgroundTransparency = 1
			TabButton.Title.TextTransparency = 1
			TabButton.Shadow.ImageTransparency = 1
			TabButton.Image.ImageTransparency = 1
			TabButton.UIStroke.Transparency = 1
		end
	end

	if Settings.Discord then
		if not isfolder(RayfieldFolder.."/Discord Invites") then
			makefolder(RayfieldFolder.."/Discord Invites")
		end
		if not isfile(RayfieldFolder.."/Discord Invites".."/"..Settings.Discord.Invite..ConfigurationExtension) then
			if request then
				request({
					Url = 'http://127.0.0.1:6463/rpc?v=1',
					Method = 'POST',
					Headers = {
						['Content-Type'] = 'application/json',
						Origin = 'https://discord.com'
					},
					Body = HttpService:JSONEncode({
						cmd = 'INVITE_BROWSER',
						nonce = HttpService:GenerateGUID(false),
						args = {code = Settings.Discord.Invite}
					})
				})
			end

			if Settings.Discord.RememberJoins then -- We do logic this way so if the developer changes this setting, the user still won't be prompted, only new users
				writefile(RayfieldFolder.."/Discord Invites".."/"..Settings.Discord.Invite..ConfigurationExtension,"Rayfield RememberJoins is true for this invite, this invite will not ask you to join again")
			end
		else

		end
	end

	if Settings.KeySystem then
		if not Settings.KeySettings then
			Passthrough = true
			return
		end

		if not isfolder(RayfieldFolder.."/Key System") then
			makefolder(RayfieldFolder.."/Key System")
		end

		if typeof(Settings.KeySettings.Key) == "string" then Settings.KeySettings.Key = {Settings.KeySettings.Key} end

		if Settings.KeySettings.GrabKeyFromSite then
			for i, Key in ipairs(Settings.KeySettings.Key) do
				local Success, Response = pcall(function()
					Settings.KeySettings.Key[i] = tostring(game:HttpGet(Key):gsub("[\n\r]", " "))
					Settings.KeySettings.Key[i] = string.gsub(Settings.KeySettings.Key[i], " ", "")
				end)
				if not Success then
					print("Rayfield | "..Key.." Error " ..tostring(Response))
				end
			end
		end

		if not Settings.KeySettings.FileName then
			Settings.KeySettings.FileName = "No file name specified"
		end

		if isfile(RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension) then
			for _, MKey in ipairs(Settings.KeySettings.Key) do
				if string.find(readfile(RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension), MKey) then
					Passthrough = true
				end
			end
		end

		if not Passthrough then
			local AttemptsRemaining = math.random(2,6)
			Rayfield.Enabled = false
			local KeyUI = game:GetObjects("rbxassetid://11380036235")[1]

			if gethui then
				KeyUI.Parent = gethui()
			elseif syn and syn.protect_gui then
				syn.protect_gui(Rayfield)
				KeyUI.Parent = CoreGui
			else
				KeyUI.Parent = CoreGui
			end

			if gethui then
				for _, Interface in ipairs(gethui():GetChildren()) do
					if Interface.Name == KeyUI.Name and Interface ~= KeyUI then
						Interface.Enabled = false
						Interface.Name = "KeyUI-Old"
					end
				end
			else
				for _, Interface in ipairs(CoreGui:GetChildren()) do
					if Interface.Name == KeyUI.Name and Interface ~= KeyUI then
						Interface.Enabled = false
						Interface.Name = "KeyUI-Old"
					end
				end
			end

			local KeyMain = KeyUI.Main
			KeyMain.Title.Text = Settings.KeySettings.Title or Settings.Name
			KeyMain.Subtitle.Text = Settings.KeySettings.Subtitle or "Key System"
			KeyMain.NoteMessage.Text = Settings.KeySettings.Note or "No instructions"

			KeyMain.Size = UDim2.new(0, 467, 0, 175)
			KeyMain.BackgroundTransparency = 1
			KeyMain.Shadow.Image.ImageTransparency = 1
			KeyMain.Title.TextTransparency = 1
			KeyMain.Subtitle.TextTransparency = 1
			KeyMain.KeyNote.TextTransparency = 1
			KeyMain.Input.BackgroundTransparency = 1
			KeyMain.Input.UIStroke.Transparency = 1
			KeyMain.Input.InputBox.TextTransparency = 1
			KeyMain.NoteTitle.TextTransparency = 1
			KeyMain.NoteMessage.TextTransparency = 1
			KeyMain.Hide.ImageTransparency = 1

			TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 187)}):Play()
			TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
			wait(0.05)
			TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			wait(0.05)
			TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			wait(0.05)
			TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			wait(0.15)
			TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 0.3}):Play()


			KeyUI.Main.Input.InputBox.FocusLost:Connect(function()
				if #KeyUI.Main.Input.InputBox.Text == 0 then return end
				local KeyFound = false
				local FoundKey = ''
				for _, MKey in ipairs(Settings.KeySettings.Key) do
					if string.find(KeyMain.Input.InputBox.Text, MKey) then
						KeyFound = true
						FoundKey = MKey
					end
				end
				if KeyFound then 
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
					TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
					TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					wait(0.51)
					Passthrough = true
					if Settings.KeySettings.SaveKey then
						if writefile then
							writefile(RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension, FoundKey)
						end
						RayfieldLibrary:Notify({Title = "Key System", Content = "The key for this script has been saved successfully"})
					end
				else
					if AttemptsRemaining == 0 then
						TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
						TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
						TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
						TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
						TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
						wait(0.45)
						game.Players.LocalPlayer:Kick("No Attempts Remaining")
						game:Shutdown()
					end
					KeyMain.Input.InputBox.Text = ""
					AttemptsRemaining = AttemptsRemaining - 1
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
					TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {Position = UDim2.new(0.495,0,0.5,0)}):Play()
					wait(0.1)
					TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {Position = UDim2.new(0.505,0,0.5,0)}):Play()
					wait(0.1)
					TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5,0,0.5,0)}):Play()
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 187)}):Play()
				end
			end)

			KeyMain.Hide.MouseButton1Click:Connect(function()
				TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
				TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
				TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
				wait(0.51)
				RayfieldLibrary:Destroy()
				KeyUI:Destroy()
			end)
		else
			Passthrough = true
		end
	end
	if Settings.KeySystem then
		repeat wait() until Passthrough
	end

	Notifications.Template.Visible = false
	Notifications.Visible = true
	Rayfield.Enabled = true
	wait(0.5)
	TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.55}):Play()
	wait(0.1)
	TweenService:Create(LoadingFrame.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	wait(0.05)
	TweenService:Create(LoadingFrame.Subtitle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	wait(0.05)
	TweenService:Create(LoadingFrame.Version, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

	Elements.Template.LayoutOrder = 100000
	Elements.Template.Visible = false

	Elements.UIPageLayout.FillDirection = Enum.FillDirection.Horizontal
	TabList.Template.Visible = false

	-- Tab
	local FirstTab = false
	local Window = {}
	function Window:CreateTab(Name,Image)
		local SDone = false
		local TabButton = TabList.Template:Clone()
		TabButton.Name = Name
		TabButton.Title.Text = Name
		TabButton.Parent = TabList
		TabButton.Title.TextWrapped = false
		TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 30, 0, 30)

		if Image then
			TabButton.Title.AnchorPoint = Vector2.new(0, 0.5)
			TabButton.Title.Position = UDim2.new(0, 37, 0.5, 0)
			TabButton.Image.Image = "rbxassetid://"..Image
			TabButton.Image.Visible = true
			TabButton.Title.TextXAlignment = Enum.TextXAlignment.Left
			TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 46, 0, 30)
		end

		TabButton.BackgroundTransparency = 1
		TabButton.Title.TextTransparency = 1
		TabButton.Shadow.ImageTransparency = 1
		TabButton.Image.ImageTransparency = 1
		TabButton.UIStroke.Transparency = 1

		TabButton.Visible = true

		-- Create Elements Page
		local TabPage = Elements.Template:Clone()
		TabPage.Name = Name
		TabPage.Visible = true

		TabPage.LayoutOrder = #Elements:GetChildren()

		for _, TemplateElement in ipairs(TabPage:GetChildren()) do
			if TemplateElement.ClassName == "Frame" and TemplateElement.Name ~= "Placeholder" then
				TemplateElement:Destroy()
			end
		end

		TabPage.Parent = Elements
		if not FirstTab then
			Elements.UIPageLayout.Animated = false
			Elements.UIPageLayout:JumpTo(TabPage)
			Elements.UIPageLayout.Animated = true
		end

		if SelectedTheme ~= RayfieldLibrary.Theme.Default then
			TabButton.Shadow.Visible = false
		end
		TabButton.UIStroke.Color = SelectedTheme.TabStroke
		-- Animate
		wait(0.1)
		if FirstTab then
			TabButton.BackgroundColor3 = SelectedTheme.TabBackground
			TabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
			TabButton.Title.TextColor3 = SelectedTheme.TabTextColor
			TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
			TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
			TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.2}):Play()
			TweenService:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()

			TweenService:Create(TabButton.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
		else
			FirstTab = Name
			TabButton.BackgroundColor3 = SelectedTheme.TabBackgroundSelected
			TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
			TabButton.Title.TextColor3 = SelectedTheme.SelectedTabTextColor
			TweenService:Create(TabButton.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.9}):Play()
			TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
			TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		end


		TabButton.Interact.MouseButton1Click:Connect(function()
			if Minimised then return end
			TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
			TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
			TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.TabBackgroundSelected}):Play()
			TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextColor3 = SelectedTheme.SelectedTabTextColor}):Play()
			TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageColor3 = SelectedTheme.SelectedTabTextColor}):Play()
			TweenService:Create(TabButton.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.9}):Play()

			for _, OtherTabButton in ipairs(TabList:GetChildren()) do
				if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton ~= TabButton and OtherTabButton.Name ~= "Placeholder" then
					TweenService:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.TabBackground}):Play()
					TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextColor3 = SelectedTheme.TabTextColor}):Play()
					TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageColor3 = SelectedTheme.TabTextColor}):Play()
					TweenService:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
					TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
					TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.2}):Play()
					TweenService:Create(OtherTabButton.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
					TweenService:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end
			end
			if Elements.UIPageLayout.CurrentPage ~= TabPage then
				TweenService:Create(Elements, TweenInfo.new(1, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 460,0, 330)}):Play()
				Elements.UIPageLayout:JumpTo(TabPage)
				wait(0.2)
				TweenService:Create(Elements, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 475,0, 366)}):Play()
			end

		end)

		local Tab = {}

		-- Button
		function Tab:CreateButton(ButtonSettings)
			local ButtonValue = {}

			local Button = Elements.Template.Button:Clone()
			Button.Name = ButtonSettings.Name
			Button.Title.Text = ButtonSettings.Name
			Button.Visible = true
			Button.Parent = TabPage

			Button.BackgroundTransparency = 1
			Button.UIStroke.Transparency = 1
			Button.Title.TextTransparency = 1

			TweenService:Create(Button, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Button.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Button.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	


			Button.Interact.MouseButton1Click:Connect(function()
				local Success, Response = pcall(ButtonSettings.Callback)
				if not Success then
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Button.Title.Text = "Callback Error"
					print("Rayfield | "..ButtonSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Button.Title.Text = ButtonSettings.Name
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.9}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				else
					SaveConfiguration()
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					wait(0.2)
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.9}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end
			end)

			Button.MouseEnter:Connect(function()
				TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.7}):Play()
			end)

			Button.MouseLeave:Connect(function()
				TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
				TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.9}):Play()
			end)

			function ButtonValue:Set(NewButton)
				Button.Title.Text = NewButton
				Button.Name = NewButton
			end

			return ButtonValue
		end

		-- ColorPicker
		function Tab:CreateColorPicker(ColorPickerSettings) -- by Throit
			ColorPickerSettings.Type = "ColorPicker"
			local ColorPicker = Elements.Template.ColorPicker:Clone()
			local Background = ColorPicker.CPBackground
			local Display = Background.Display
			local Main = Background.MainCP
			local Slider = ColorPicker.ColorSlider
			ColorPicker.ClipsDescendants = true
			ColorPicker.Name = ColorPickerSettings.Name
			ColorPicker.Title.Text = ColorPickerSettings.Name
			ColorPicker.Visible = true
			ColorPicker.Parent = TabPage
			ColorPicker.Size = UDim2.new(1, -10, 0.028, 35)
			Background.Size = UDim2.new(0, 39, 0, 22)
			Display.BackgroundTransparency = 0
			Main.MainPoint.ImageTransparency = 1
			ColorPicker.Interact.Size = UDim2.new(1, 0, 1, 0)
			ColorPicker.Interact.Position = UDim2.new(0.5, 0, 0.5, 0)
			ColorPicker.RGB.Position = UDim2.new(0, 17, 0, 70)
			ColorPicker.HexInput.Position = UDim2.new(0, 17, 0, 90)
			Main.ImageTransparency = 1
			Background.BackgroundTransparency = 1



			local opened = false 
			local mouse = game.Players.LocalPlayer:GetMouse()
			Main.Image = "http://www.roblox.com/asset/?id=11415645739"
			local mainDragging = false 
			local sliderDragging = false 
			ColorPicker.Interact.MouseButton1Down:Connect(function()
				if not opened then
					opened = true 
					TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0.224, 40)}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 173, 0, 86)}):Play()
					TweenService:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0.289, 0, 0.5, 0)}):Play()
					TweenService:Create(ColorPicker.RGB, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 40)}):Play()
					TweenService:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 73)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0.574, 0, 1, 0)}):Play()
					TweenService:Create(Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
					TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0.1}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
				else
					opened = false
					TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0.028, 35)}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 39, 0, 22)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 1, 0)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
					TweenService:Create(ColorPicker.RGB, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 70)}):Play()
					TweenService:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 90)}):Play()
					TweenService:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
					TweenService:Create(Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				end
			end)

			game:GetService("UserInputService").InputEnded:Connect(function(input, gameProcessed) if input.UserInputType == Enum.UserInputType.MouseButton1 then 
					mainDragging = false
					sliderDragging = false
				end end)
			Main.MouseButton1Down:Connect(function()
				if opened then
					mainDragging = true 
				end
			end)
			Main.MainPoint.MouseButton1Down:Connect(function()
				if opened then
					mainDragging = true 
				end
			end)
			Slider.MouseButton1Down:Connect(function()
				sliderDragging = true 
			end)
			Slider.SliderPoint.MouseButton1Down:Connect(function()
				sliderDragging = true 
			end)
			local h,s,v = ColorPickerSettings.Color:ToHSV()
			local color = Color3.fromHSV(h,s,v) 
			local hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
			ColorPicker.HexInput.InputBox.Text = hex
			local function setDisplay()
				--Main
				Main.MainPoint.Position = UDim2.new(s,-Main.MainPoint.AbsoluteSize.X/2,1-v,-Main.MainPoint.AbsoluteSize.Y/2)
				Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
				Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
				Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
				--Slider 
				local x = h * Slider.AbsoluteSize.X
				Slider.SliderPoint.Position = UDim2.new(0,x-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
				Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h,1,1)
				local color = Color3.fromHSV(h,s,v) 
				local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
				ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
				ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
				ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
				hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
				ColorPicker.HexInput.InputBox.Text = hex
			end
			setDisplay()
			ColorPicker.HexInput.InputBox.FocusLost:Connect(function()
				if not pcall(function()
						local r, g, b = string.match(ColorPicker.HexInput.InputBox.Text, "^#?(%w%w)(%w%w)(%w%w)$")
						local rgbColor = Color3.fromRGB(tonumber(r, 16),tonumber(g, 16), tonumber(b, 16))
						h,s,v = rgbColor:ToHSV()
						hex = ColorPicker.HexInput.InputBox.Text
						setDisplay()
						ColorPickerSettings.Color = rgbColor
					end) 
				then 
					ColorPicker.HexInput.InputBox.Text = hex 
				end
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
				ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
				SaveConfiguration()
			end)
			--RGB
			local function rgbBoxes(box,toChange)
				local value = tonumber(box.Text) 
				local color = Color3.fromHSV(h,s,v) 
				local oldR,oldG,oldB = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
				local save 
				if toChange == "R" then save = oldR;oldR = value elseif toChange == "G" then save = oldG;oldG = value else save = oldB;oldB = value end
				if value then 
					value = math.clamp(value,0,255)
					h,s,v = Color3.fromRGB(oldR,oldG,oldB):ToHSV()

					setDisplay()
				else 
					box.Text = tostring(save)
				end
				local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
				ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
				SaveConfiguration()
			end
			ColorPicker.RGB.RInput.InputBox.FocusLost:connect(function()
				rgbBoxes(ColorPicker.RGB.RInput.InputBox,"R")
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
			end)
			ColorPicker.RGB.GInput.InputBox.FocusLost:connect(function()
				rgbBoxes(ColorPicker.RGB.GInput.InputBox,"G")
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
			end)
			ColorPicker.RGB.BInput.InputBox.FocusLost:connect(function()
				rgbBoxes(ColorPicker.RGB.BInput.InputBox,"B")
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
			end)

			game:GetService("RunService").RenderStepped:connect(function()
				if mainDragging then 
					local localX = math.clamp(mouse.X-Main.AbsolutePosition.X,0,Main.AbsoluteSize.X)
					local localY = math.clamp(mouse.Y-Main.AbsolutePosition.Y,0,Main.AbsoluteSize.Y)
					Main.MainPoint.Position = UDim2.new(0,localX-Main.MainPoint.AbsoluteSize.X/2,0,localY-Main.MainPoint.AbsoluteSize.Y/2)
					s = localX / Main.AbsoluteSize.X
					v = 1 - (localY / Main.AbsoluteSize.Y)
					Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
					Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
					Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
					local color = Color3.fromHSV(h,s,v) 
					local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					SaveConfiguration()
				end
				if sliderDragging then 
					local localX = math.clamp(mouse.X-Slider.AbsolutePosition.X,0,Slider.AbsoluteSize.X)
					h = localX / Slider.AbsoluteSize.X
					Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
					Slider.SliderPoint.Position = UDim2.new(0,localX-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
					Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h,1,1)
					Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
					Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
					local color = Color3.fromHSV(h,s,v) 
					local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					SaveConfiguration()
				end
			end)

			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and ColorPickerSettings.Flag then
					RayfieldLibrary.Flags[ColorPickerSettings.Flag] = ColorPickerSettings
				end
			end

			function ColorPickerSettings:Set(RGBColor)
				ColorPickerSettings.Color = RGBColor
				h,s,v = ColorPickerSettings.Color:ToHSV()
				color = Color3.fromHSV(h,s,v)
				setDisplay()
			end

			return ColorPickerSettings
		end

		-- Section
		function Tab:CreateSection(SectionName)

			local SectionValue = {}

			if SDone then
				local SectionSpace = Elements.Template.SectionSpacing:Clone()
				SectionSpace.Visible = true
				SectionSpace.Parent = TabPage
			end

			local Section = Elements.Template.SectionTitle:Clone()
			Section.Title.Text = SectionName
			Section.Visible = true
			Section.Parent = TabPage

			Section.Title.TextTransparency = 1
			TweenService:Create(Section.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

			function SectionValue:Set(NewSection)
				Section.Title.Text = NewSection
			end

			SDone = true

			return SectionValue
		end

		-- Label
		function Tab:CreateLabel(LabelText)
			local LabelValue = {}

			local Label = Elements.Template.Label:Clone()
			Label.Title.Text = LabelText
			Label.Visible = true
			Label.Parent = TabPage

			Label.BackgroundTransparency = 1
			Label.UIStroke.Transparency = 1
			Label.Title.TextTransparency = 1

			Label.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
			Label.UIStroke.Color = SelectedTheme.SecondaryElementStroke

			TweenService:Create(Label, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Label.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Label.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			function LabelValue:Set(NewLabel)
				Label.Title.Text = NewLabel
			end

			return LabelValue
		end

		-- Paragraph
		function Tab:CreateParagraph(ParagraphSettings)
			local ParagraphValue = {}

			local Paragraph = Elements.Template.Paragraph:Clone()
			Paragraph.Title.Text = ParagraphSettings.Title
			Paragraph.Content.Text = ParagraphSettings.Content
			Paragraph.Visible = true
			Paragraph.Parent = TabPage

			Paragraph.Content.Size = UDim2.new(0, 438, 0, Paragraph.Content.TextBounds.Y)
			Paragraph.Content.Position = UDim2.new(1, -10, 0.575,0 )
			Paragraph.Size = UDim2.new(1, -10, 0, Paragraph.Content.TextBounds.Y + 40)

			Paragraph.BackgroundTransparency = 1
			Paragraph.UIStroke.Transparency = 1
			Paragraph.Title.TextTransparency = 1
			Paragraph.Content.TextTransparency = 1

			Paragraph.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
			Paragraph.UIStroke.Color = SelectedTheme.SecondaryElementStroke

			TweenService:Create(Paragraph, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Paragraph.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Paragraph.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	
			TweenService:Create(Paragraph.Content, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			function ParagraphValue:Set(NewParagraphSettings)
				Paragraph.Title.Text = NewParagraphSettings.Title
				Paragraph.Content.Text = NewParagraphSettings.Content
			end

			return ParagraphValue
		end

		-- Input
		function Tab:CreateInput(InputSettings)
			local Input = Elements.Template.Input:Clone()
			Input.Name = InputSettings.Name
			Input.Title.Text = InputSettings.Name
			Input.Visible = true
			Input.Parent = TabPage

			Input.BackgroundTransparency = 1
			Input.UIStroke.Transparency = 1
			Input.Title.TextTransparency = 1

			Input.InputFrame.BackgroundColor3 = SelectedTheme.InputBackground
			Input.InputFrame.UIStroke.Color = SelectedTheme.InputStroke

			TweenService:Create(Input, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Input.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Input.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			Input.InputFrame.InputBox.PlaceholderText = InputSettings.PlaceholderText
			Input.InputFrame.Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)

			Input.InputFrame.InputBox.FocusLost:Connect(function()


				local Success, Response = pcall(function()
					InputSettings.Callback(Input.InputFrame.InputBox.Text)
				end)
				if not Success then
					TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Input.Title.Text = "Callback Error"
					print("Rayfield | "..InputSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Input.Title.Text = InputSettings.Name
					TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end

				if InputSettings.RemoveTextAfterFocusLost then
					Input.InputFrame.InputBox.Text = ""
				end
				SaveConfiguration()
			end)

			Input.MouseEnter:Connect(function()
				TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)

			Input.MouseLeave:Connect(function()
				TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			Input.InputFrame.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
				TweenService:Create(Input.InputFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)}):Play()
			end)

			local InputSettings = {}
			function InputSettings:Set(text) --Doesnt fire the event
				Input.InputFrame.InputBox.Text = text
			end
			return InputSettings
		end

		-- Dropdown
		function Tab:CreateDropdown(DropdownSettings)
			local Dropdown = Elements.Template.Dropdown:Clone()
			if string.find(DropdownSettings.Name,"closed") then
				Dropdown.Name = "Dropdown"
			else
				Dropdown.Name = DropdownSettings.Name
			end
			Dropdown.Title.Text = DropdownSettings.Name
			Dropdown.Visible = true
			Dropdown.Parent = TabPage

			Dropdown.List.Visible = false

			if typeof(DropdownSettings.CurrentOption) == "string" then
				DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption}
			end

			if not DropdownSettings.MultipleOptions then
				DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption[1]}
			end

			if DropdownSettings.MultipleOptions then
				if #DropdownSettings.CurrentOption == 1 then
					Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
				elseif #DropdownSettings.CurrentOption == 0 then
					Dropdown.Selected.Text = "None"
				else
					Dropdown.Selected.Text = "Various"
				end
			else
				Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
			end


			Dropdown.BackgroundTransparency = 1
			Dropdown.UIStroke.Transparency = 1
			Dropdown.Title.TextTransparency = 1

			Dropdown.Size = UDim2.new(1, -10, 0, 45)

			TweenService:Create(Dropdown, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Dropdown.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			for _, ununusedoption in ipairs(Dropdown.List:GetChildren()) do
				if ununusedoption.ClassName == "Frame" and ununusedoption.Name ~= "Placeholder" then
					ununusedoption:Destroy()
				end
			end

			Dropdown.Toggle.Rotation = 180

			Dropdown.Interact.MouseButton1Click:Connect(function()
				TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				wait(0.1)
				TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				if Debounce then return end
				if Dropdown.List.Visible then
					Debounce = true
					TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0, 45)}):Play()
					for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
						if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "Placeholder" then
							TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
					end
					TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
					TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
					wait(0.35)
					Dropdown.List.Visible = false
					Debounce = false
				else
					TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0, 180)}):Play()
					Dropdown.List.Visible = true
					TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 0.7}):Play()
					TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 0}):Play()	
					for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
						if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "Placeholder" then
							TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						end
					end
				end
			end)

			Dropdown.MouseEnter:Connect(function()
				if not Dropdown.List.Visible then
					TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				end
			end)

			Dropdown.MouseLeave:Connect(function()
				TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			for _, Option in ipairs(DropdownSettings.Options) do
				local DropdownOption = Elements.Template.Dropdown.List.Template:Clone()
				DropdownOption.Name = Option
				DropdownOption.Title.Text = Option
				DropdownOption.Parent = Dropdown.List
				DropdownOption.Visible = true

				if DropdownSettings.CurrentOption == Option then
					DropdownOption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				end

				DropdownOption.BackgroundTransparency = 1
				DropdownOption.UIStroke.Transparency = 1
				DropdownOption.Title.TextTransparency = 1

				--local Dropdown = Tab:CreateDropdown({
				--	Name = "Dropdown Example",
				--	Options = {"Option 1","Option 2"},
				--	CurrentOption = {"Option 1"},
				--  MultipleOptions = true,
				--	Flag = "Dropdown1",
				--	Callback = function(TableOfOptions)

				--	end,
				--})


				DropdownOption.Interact.ZIndex = 50
				DropdownOption.Interact.MouseButton1Click:Connect(function()
					if not DropdownSettings.MultipleOptions and table.find(DropdownSettings.CurrentOption, Option) then 
						return
					end

					if table.find(DropdownSettings.CurrentOption, Option) then
						table.remove(DropdownSettings.CurrentOption, table.find(DropdownSettings.CurrentOption, Option))
						if DropdownSettings.MultipleOptions then
							if #DropdownSettings.CurrentOption == 1 then
								Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
							elseif #DropdownSettings.CurrentOption == 0 then
								Dropdown.Selected.Text = "None"
							else
								Dropdown.Selected.Text = "Various"
							end
						else
							Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
						end
					else
						if not DropdownSettings.MultipleOptions then
							table.clear(DropdownSettings.CurrentOption)
						end
						table.insert(DropdownSettings.CurrentOption, Option)
						if DropdownSettings.MultipleOptions then
							if #DropdownSettings.CurrentOption == 1 then
								Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
							elseif #DropdownSettings.CurrentOption == 0 then
								Dropdown.Selected.Text = "None"
							else
								Dropdown.Selected.Text = "Various"
							end
						else
							Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
						end
						TweenService:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						TweenService:Create(DropdownOption, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
						Debounce = true
						wait(0.2)
						TweenService:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					end


					local Success, Response = pcall(function()
						DropdownSettings.Callback(DropdownSettings.CurrentOption)
					end)

					if not Success then
						TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						Dropdown.Title.Text = "Callback Error"
						print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
						wait(0.5)
						Dropdown.Title.Text = DropdownSettings.Name
						TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
						TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					end

					for _, droption in ipairs(Dropdown.List:GetChildren()) do
						if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" and not table.find(DropdownSettings.CurrentOption, droption.Name) then
							TweenService:Create(droption, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
						end
					end
					if not DropdownSettings.MultipleOptions then
						wait(0.1)
						TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0, 45)}):Play()
						for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
							if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "Placeholder" then
								TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
								TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
								TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
							end
						end
						TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
						TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
						wait(0.35)
						Dropdown.List.Visible = false
					end
					Debounce = false	
					SaveConfiguration()
				end)
			end

			for _, droption in ipairs(Dropdown.List:GetChildren()) do
				if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" then
					if not table.find(DropdownSettings.CurrentOption, droption.Name) then
						droption.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
					else
						droption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					end
				end
			end

			function DropdownSettings:Set(NewOption)
				DropdownSettings.CurrentOption = NewOption

				if typeof(DropdownSettings.CurrentOption) == "string" then
					DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption}
				end

				if not DropdownSettings.MultipleOptions then
					DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption[1]}
				end

				if DropdownSettings.MultipleOptions then
					if #DropdownSettings.CurrentOption == 1 then
						Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
					elseif #DropdownSettings.CurrentOption == 0 then
						Dropdown.Selected.Text = "None"
					else
						Dropdown.Selected.Text = "Various"
					end
				else
					Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
				end


				local Success, Response = pcall(function()
					DropdownSettings.Callback(NewOption)
				end)
				if not Success then
					TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Dropdown.Title.Text = "Callback Error"
					print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Dropdown.Title.Text = DropdownSettings.Name
					TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end

				for _, droption in ipairs(Dropdown.List:GetChildren()) do
					if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" then
						if not table.find(DropdownSettings.CurrentOption, droption.Name) then
							droption.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
						else
							droption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
						end
					end
				end
				--SaveConfiguration()
			end

			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and DropdownSettings.Flag then
					RayfieldLibrary.Flags[DropdownSettings.Flag] = DropdownSettings
				end
			end

			return DropdownSettings
		end

		-- Keybind
		function Tab:CreateKeybind(KeybindSettings)
			local CheckingForKey = false
			local Keybind = Elements.Template.Keybind:Clone()
			Keybind.Name = KeybindSettings.Name
			Keybind.Title.Text = KeybindSettings.Name
			Keybind.Visible = true
			Keybind.Parent = TabPage

			Keybind.BackgroundTransparency = 1
			Keybind.UIStroke.Transparency = 1
			Keybind.Title.TextTransparency = 1

			Keybind.KeybindFrame.BackgroundColor3 = SelectedTheme.InputBackground
			Keybind.KeybindFrame.UIStroke.Color = SelectedTheme.InputStroke

			TweenService:Create(Keybind, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Keybind.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
			Keybind.KeybindFrame.Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)

			Keybind.KeybindFrame.KeybindBox.Focused:Connect(function()
				CheckingForKey = true
				Keybind.KeybindFrame.KeybindBox.Text = ""
			end)
			Keybind.KeybindFrame.KeybindBox.FocusLost:Connect(function()
				CheckingForKey = false
				if Keybind.KeybindFrame.KeybindBox.Text == nil or "" then
					Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
					SaveConfiguration()
				end
			end)

			Keybind.MouseEnter:Connect(function()
				TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)

			Keybind.MouseLeave:Connect(function()
				TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			UserInputService.InputBegan:Connect(function(input, processed)

				if CheckingForKey then
					if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode ~= Enum.KeyCode.K then
						local SplitMessage = string.split(tostring(input.KeyCode), ".")
						local NewKeyNoEnum = SplitMessage[3]
						Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeyNoEnum)
						KeybindSettings.CurrentKeybind = tostring(NewKeyNoEnum)
						Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
						SaveConfiguration()
					end
				elseif KeybindSettings.CurrentKeybind ~= nil and (input.KeyCode == Enum.KeyCode[KeybindSettings.CurrentKeybind] and not processed) then -- Test
					local Held = true
					local Connection
					Connection = input.Changed:Connect(function(prop)
						if prop == "UserInputState" then
							Connection:Disconnect()
							Held = false
						end
					end)

					if not KeybindSettings.HoldToInteract then
						local Success, Response = pcall(KeybindSettings.Callback)
						if not Success then
							TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
							TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							Keybind.Title.Text = "Callback Error"
							print("Rayfield | "..KeybindSettings.Name.." Callback Error " ..tostring(Response))
							wait(0.5)
							Keybind.Title.Text = KeybindSettings.Name
							TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
							TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
						end
					else
						wait(0.25)
						if Held then
							local Loop; Loop = RunService.Stepped:Connect(function()
								if not Held then
									KeybindSettings.Callback(false) -- maybe pcall this
									Loop:Disconnect()
								else
									KeybindSettings.Callback(true) -- maybe pcall this
								end
							end)	
						end
					end
				end
			end)

			Keybind.KeybindFrame.KeybindBox:GetPropertyChangedSignal("Text"):Connect(function()
				TweenService:Create(Keybind.KeybindFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)}):Play()
			end)

			function KeybindSettings:Set(NewKeybind)
				Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeybind)
				KeybindSettings.CurrentKeybind = tostring(NewKeybind)
				Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
				SaveConfiguration()
			end
			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and KeybindSettings.Flag then
					RayfieldLibrary.Flags[KeybindSettings.Flag] = KeybindSettings
				end
			end
			return KeybindSettings
		end

		-- Toggle
		function Tab:CreateToggle(ToggleSettings)
			local ToggleValue = {}

			local Toggle = Elements.Template.Toggle:Clone()
			Toggle.Name = ToggleSettings.Name
			Toggle.Title.Text = ToggleSettings.Name
			Toggle.Visible = true
			Toggle.Parent = TabPage

			Toggle.BackgroundTransparency = 1
			Toggle.UIStroke.Transparency = 1
			Toggle.Title.TextTransparency = 1
			Toggle.Switch.BackgroundColor3 = SelectedTheme.ToggleBackground

			if SelectedTheme ~= RayfieldLibrary.Theme.Default then
				Toggle.Switch.Shadow.Visible = false
			end

			TweenService:Create(Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Toggle.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			if not ToggleSettings.CurrentValue then
				Toggle.Switch.Indicator.Position = UDim2.new(1, -40, 0.5, 0)
				Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleDisabledStroke
				Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleDisabled
				Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleDisabledOuterStroke
			else
				Toggle.Switch.Indicator.Position = UDim2.new(1, -20, 0.5, 0)
				Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleEnabledStroke
				Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleEnabled
				Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleEnabledOuterStroke
			end

			Toggle.MouseEnter:Connect(function()
				TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)

			Toggle.MouseLeave:Connect(function()
				TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			Toggle.Interact.MouseButton1Click:Connect(function()
				if ToggleSettings.CurrentValue then
					ToggleSettings.CurrentValue = false
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleDisabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleDisabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleDisabledOuterStroke}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()	
				else
					ToggleSettings.CurrentValue = true
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleEnabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleEnabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleEnabledOuterStroke}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()	
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()		
				end

				local Success, Response = pcall(function()
					ToggleSettings.Callback(ToggleSettings.CurrentValue)
				end)
				if not Success then
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Toggle.Title.Text = "Callback Error"
					print("Rayfield | "..ToggleSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Toggle.Title.Text = ToggleSettings.Name
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end


				SaveConfiguration()
			end)

			function ToggleSettings:Set(NewToggleValue)
				if NewToggleValue then
					ToggleSettings.CurrentValue = true
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleEnabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleEnabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Color3.fromRGB(100,100,100)}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()	
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()	
				else
					ToggleSettings.CurrentValue = false
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleDisabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleDisabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Color3.fromRGB(65,65,65)}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()	
				end
				local Success, Response = pcall(function()
					ToggleSettings.Callback(ToggleSettings.CurrentValue)
				end)
				if not Success then
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Toggle.Title.Text = "Callback Error"
					print("Rayfield | "..ToggleSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Toggle.Title.Text = ToggleSettings.Name
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end
				SaveConfiguration()
			end

			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and ToggleSettings.Flag then
					RayfieldLibrary.Flags[ToggleSettings.Flag] = ToggleSettings
				end
			end

			return ToggleSettings
		end

		-- Slider
		function Tab:CreateSlider(SliderSettings)
			local Dragging = false
			local Slider = Elements.Template.Slider:Clone()
			Slider.Name = SliderSettings.Name
			Slider.Title.Text = SliderSettings.Name
			Slider.Visible = true
			Slider.Parent = TabPage

			Slider.BackgroundTransparency = 1
			Slider.UIStroke.Transparency = 1
			Slider.Title.TextTransparency = 1

			if SelectedTheme ~= RayfieldLibrary.Theme.Default then
				Slider.Main.Shadow.Visible = false
			end

			Slider.Main.BackgroundColor3 = SelectedTheme.SliderBackground
			Slider.Main.UIStroke.Color = SelectedTheme.SliderStroke
			Slider.Main.Progress.BackgroundColor3 = SelectedTheme.SliderProgress

			TweenService:Create(Slider, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Slider.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Slider.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			Slider.Main.Progress.Size =	UDim2.new(0, Slider.Main.AbsoluteSize.X * ((SliderSettings.CurrentValue + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (SliderSettings.CurrentValue / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0)

			if not SliderSettings.Suffix then
				Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue)
			else
				Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue) .. " " .. SliderSettings.Suffix
			end


			Slider.MouseEnter:Connect(function()
				TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)

			Slider.MouseLeave:Connect(function()
				TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			Slider.Main.Interact.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 then 
					Dragging = true 
				end 
			end)
			Slider.Main.Interact.InputEnded:Connect(function(Input) 
				if Input.UserInputType == Enum.UserInputType.MouseButton1 then 
					Dragging = false 
				end 
			end)

			Slider.Main.Interact.MouseButton1Down:Connect(function(X)
				local Current = Slider.Main.Progress.AbsolutePosition.X + Slider.Main.Progress.AbsoluteSize.X
				local Start = Current
				local Location = X
				local Loop; Loop = RunService.Stepped:Connect(function()
					if Dragging then
						Location = UserInputService:GetMouseLocation().X
						Current = Current + 0.025 * (Location - Start)

						if Location < Slider.Main.AbsolutePosition.X then
							Location = Slider.Main.AbsolutePosition.X
						elseif Location > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
							Location = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
						end

						if Current < Slider.Main.AbsolutePosition.X + 5 then
							Current = Slider.Main.AbsolutePosition.X + 5
						elseif Current > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
							Current = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
						end

						if Current <= Location and (Location - Start) < 0 then
							Start = Location
						elseif Current >= Location and (Location - Start) > 0 then
							Start = Location
						end
						TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Current - Slider.Main.AbsolutePosition.X, 1, 0)}):Play()
						local NewValue = SliderSettings.Range[1] + (Location - Slider.Main.AbsolutePosition.X) / Slider.Main.AbsoluteSize.X * (SliderSettings.Range[2] - SliderSettings.Range[1])

						NewValue = math.floor(NewValue / SliderSettings.Increment + 0.5) * (SliderSettings.Increment * 10000000) / 10000000
						if not SliderSettings.Suffix then
							Slider.Main.Information.Text = tostring(NewValue)
						else
							Slider.Main.Information.Text = tostring(NewValue) .. " " .. SliderSettings.Suffix
						end

						if SliderSettings.CurrentValue ~= NewValue then
							local Success, Response = pcall(function()
								SliderSettings.Callback(NewValue)
							end)
							if not Success then
								TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
								TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
								Slider.Title.Text = "Callback Error"
								print("Rayfield | "..SliderSettings.Name.." Callback Error " ..tostring(Response))
								wait(0.5)
								Slider.Title.Text = SliderSettings.Name
								TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
								TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							end

							SliderSettings.CurrentValue = NewValue
							SaveConfiguration()
						end
					else
						TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Location - Slider.Main.AbsolutePosition.X > 5 and Location - Slider.Main.AbsolutePosition.X or 5, 1, 0)}):Play()
						Loop:Disconnect()
					end
				end)
			end)

			function SliderSettings:Set(NewVal)
				TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Slider.Main.AbsoluteSize.X * ((NewVal + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (NewVal / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0)}):Play()
				Slider.Main.Information.Text = tostring(NewVal) .. " " .. SliderSettings.Suffix
				local Success, Response = pcall(function()
					SliderSettings.Callback(NewVal)
				end)
				if not Success then
					TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Slider.Title.Text = "Callback Error"
					print("Rayfield | "..SliderSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Slider.Title.Text = SliderSettings.Name
					TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end
				SliderSettings.CurrentValue = NewVal
				SaveConfiguration()
			end
			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and SliderSettings.Flag then
					RayfieldLibrary.Flags[SliderSettings.Flag] = SliderSettings
				end
			end
			return SliderSettings
		end


		return Tab
	end

	Elements.Visible = true

	wait(0.7)
	TweenService:Create(LoadingFrame.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(LoadingFrame.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(LoadingFrame.Version, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	wait(0.2)
	TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 475)}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.4}):Play()

	Topbar.BackgroundTransparency = 1
	Topbar.Divider.Size = UDim2.new(0, 0, 0, 1)
	Topbar.CornerRepair.BackgroundTransparency = 1
	Topbar.Title.TextTransparency = 1
	Topbar.Theme.ImageTransparency = 1
	Topbar.ChangeSize.ImageTransparency = 1
	Topbar.Hide.ImageTransparency = 1

	wait(0.5)
	Topbar.Visible = true
	TweenService:Create(Topbar, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Divider, TweenInfo.new(1, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, 1)}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Theme, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
	wait(0.1)
	TweenService:Create(Topbar.ChangeSize, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Hide, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
	wait(0.3)

	return Window
end


function RayfieldLibrary:Destroy()
	Rayfield:Destroy()
end

Topbar.ChangeSize.MouseButton1Click:Connect(function()
	if Debounce then return end
	if Minimised then
		Minimised = false
		Maximise()
	else
		Minimised = true
		Minimise()
	end
end)

Topbar.Hide.MouseButton1Click:Connect(function()
	if Debounce then return end
	if Hidden then
		Hidden = false
		Minimised = false
		Unhide()
	else
		Hidden = true
		Hide()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if (input.KeyCode == Enum.KeyCode.K and not processed) then
		if Debounce then return end
		if Hidden then
			Hidden = false
			Unhide()
		else
			Hidden = true
			Hide()
		end
	end
end)

for _, TopbarButton in ipairs(Topbar:GetChildren()) do
	if TopbarButton.ClassName == "ImageButton" then
		TopbarButton.MouseEnter:Connect(function()
			TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
		end)

		TopbarButton.MouseLeave:Connect(function()
			TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
		end)

		TopbarButton.MouseButton1Click:Connect(function()
			TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
		end)
	end
end


function RayfieldLibrary:LoadConfiguration()
	if CEnabled then
		pcall(function()
			if isfile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension) then
				LoadConfiguration(readfile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension))
				RayfieldLibrary:Notify({Title = "Configuration Loaded", Content = "The configuration file for this script has been loaded from a previous session"})
			end
		end)
	end
end

task.delay(3.5, RayfieldLibrary.LoadConfiguration, RayfieldLibrary)
if Rayfield:FindFirstChild("Notice") then
	Rayfield.Notice.Visible = true
	Rayfield.Notice.Interact.MouseButton1Click:Connect(function()
		Rayfield.Notice.Visible = false
	end)
end

	return RayfieldLibrary

]=]

-- =====================================================================
-- ВСТРОЕННЫЙ Linoria (violin-suzutsuki/LinoriaLib/Library.lua) —
-- ДВИЖОК-ФОЛБЭК: ни одного ассета/GetObjects, всё на чистом Instance.new.
-- =====================================================================
local LINORIA_SRC = [=[
local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ScreenGui.Name = 'SpermaLinoria';
pcall(function() ScreenGui:SetAttribute('SpermaCurrent', true) end);
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;

    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );

            if ObjPos.Y > (Cutoff or 40) then
                return;
            end;

            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );

                RenderStepped:Wait();
            end;
        end;
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an 'active' list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the 'Visible' propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    -- Only used for signals not attached to library instances, as those should be cleaned up on object destruction by Roblox
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    -- Unload all of the signals
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

     -- Call our unload callback, maybe to undo some hooks etc
    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        -- local Container = self.Container;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        -- Transparency image taken from https://github.com/matas3535/SplixPrivateDrawingLibrary/blob/main/Library.lua cus i'm lazy
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        -- 1/16/23
        -- Rewrote this to be placed inside the Library ScreenGui
        -- There was some issue which caused RelativeOffset to be way off
        -- Thus the color picker would never show

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle'; -- Always, Toggle, Hold
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        -- TODO: Eventually redo this
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Outer, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end


        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = Container;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        -- https://devforum.roblox.com/t/how-to-make-textboxes-follow-current-cursor-position/1368429/6
        -- thank you nicemike40 :)

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- we aren't focused, or we fit so be normal
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- we are focused and don't fit, so adjust position
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- calculate pixel width of text from start to cursor
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- check if we're inside the box with the cursor
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- adjust if necessary
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;


            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType; -- can be either 'Player' or 'Team'
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = 'Black';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- < Create other UI elements >
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });

    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = 'AccentColor';
    });

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);



    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true)

    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(NotifyInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
    };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:MakeDraggable(Outer, 25);

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    });

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'AccentColor';
    });

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 1;
        Parent = Inner;
    });

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        ZIndex = 1;
        Parent = Inner;
    });

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, 21);
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 2;
        Parent = MainSectionInner;
    });
    

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0);
            ZIndex = 1;
            Parent = TabArea;
        });

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Name;
            ZIndex = 1;
            Parent = TabButton;
        });

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = 'MainColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do
                Tab:HideTab();
            end;

            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;

                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                -- Show first tab (number is 2 cus of the UIListLayout that also sits in that instance)
                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);

        -- This was the first tab added, so we show it by default.
        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then
            -- A bit scuffed, but if we're going from not toggled -> toggled we want to show the frame immediately so that the fade is visible.
            Outer.Visible = true;

            task.spawn(function()
                -- TODO: add cursor fade?
                local State = InputService.MouseIconEnabled;

                local Cursor = Drawing.new('Triangle');
                Cursor.Thickness = 1;
                Cursor.Filled = true;
                Cursor.Visible = true;

                local CursorOutline = Drawing.new('Triangle');
                CursorOutline.Thickness = 1;
                CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0, 0, 0);
                CursorOutline.Visible = true;

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;

                    local mPos = InputService:GetMouseLocation();

                    Cursor.Color = Library.AccentColor;

                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);

                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;

                    RenderStepped:Wait();
                end;

                InputService.MouseIconEnabled = State;

                Cursor:Remove();
                CursorOutline:Remove();
            end);
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};

            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];

            if (not Cache) then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;

                if Cache[Prop] == 1 then
                    continue;
                end;

                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);

        Outer.Visible = Toggled;

        Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library
]=]

print("[SpermaHub] GUI режим: Linoria (первичная, безассетная) — фолбэк Rayfield")

local RayLib = nil
local RayWindow = nil
local LinLib = nil
local LinWindow = nil
local guiLastErr = "unknown"
do
    local function tryLib(src, tag, libName)
        if not src then return nil end
        local fn = loadstring(src, libName == "linoria" and "@linoria" or "@rayfield")
        local okL, lib = pcall(function() if fn then return fn() end return nil end)
        if okL and type(lib) == "table" and lib.CreateWindow then
            print("[SpermaHub] " .. libName .. " загружен: " .. tag)
            return lib
        end
        guiLastErr = tostring(lib)
        warn("[SpermaHub] " .. libName .. " не завёлся (" .. tag .. "): " .. tostring(lib))
        return nil
    end

    -- 1) LINORIA — безассетный движок (чистый Instance.new; точно заводится везде)
    LinLib = tryLib(LINORIA_SRC, "встроенная копия", "linoria")
    if not LinLib then
        local LU = {
            "https://cdn.jsdelivr.net/gh/violin-suzutsuki/LinoriaLib@main/Library.lua",
            "https://fastly.jsdelivr.net/gh/violin-suzutsuki/LinoriaLib@main/Library.lua",
            "https://gcore.jsdelivr.net/gh/violin-suzutsuki/LinoriaLib@main/Library.lua",
        }
        for _, u in ipairs(LU) do
            local ok, r = pcall(function() return game:HttpGet(u) end)
            if ok and type(r) == "string" and #r > 50000 and r:find("CreateWindow", 1, true) then
                LinLib = tryLib(r, u, "linoria")
                if LinLib then break end
            end
        end
    end
    if LinLib then
        local okW, w = pcall(function()
            return LinLib:CreateWindow({ Title = "SpermaHub", Center = true, AutoShow = false, MenuFadeTime = 0.15 })
        end)
        if okW and w then
            LinWindow = w
            print("[SpermaHub] Linoria window OK (toggle: RightShift)")
        else
            guiLastErr = tostring(w)
            warn("[SpermaHub] Linoria CreateWindow fail: " .. tostring(w))
            LinLib = nil
        end
    end

    -- 2) RAYFIELD — фолбэк (если Linoria вдруг не завелась)
    if not LinLib then
        warn("[SpermaHub] Linoria не завёлся — пробую Rayfield...")
        RayLib = tryLib(RAYFIELD_SRC, "встроенная копия", "rayfield")
        if not RayLib then
            local RU = {
                "https://cdn.jsdelivr.net/gh/jensonhirst/Rayfield@main/source",
                "https://fastly.jsdelivr.net/gh/jensonhirst/Rayfield@main/source",
                "https://cdn.jsdelivr.net/gh/SiriusSoftwareLtd/Rayfield@main/source.lua",
            }
            for _, u in ipairs(RU) do
                local ok, r = pcall(function() return game:HttpGet(u) end)
                if ok and type(r) == "string" and #r > 50000 and r:find("Rayfield", 1, true) then
                    RayLib = tryLib(r, u, "rayfield")
                    if RayLib then break end
                end
            end
        end
        if RayLib then
            local heirsW = { LP.PlayerGui }
            pcall(function() if gethui then table.insert(heirsW, gethui()) end end)
            pcall(function() table.insert(heirsW, game.CoreGui) end)
            for _, parent in ipairs(heirsW) do
                pcall(function()
                    for _, gui in ipairs(parent:GetChildren()) do
                        if gui:IsA("ScreenGui") and (gui.Name == "Rayfield" or gui.Name == "KeyUI") then
                            gui:Destroy()
                        end
                    end
                end)
            end
            local okWin, win = pcall(function()
                return RayLib:CreateWindow({
                    Name = "SpermaHub",
                    LoadingTitle = "SpermaHub",
                    LoadingSubtitle = "by eni",
                    ConfigurationSaving = { Enabled = false },
                    Discord = { Enabled = false },
                    KeySystem = false,
                })
            end)
            if okWin and win then
                RayWindow = win
                print("[SpermaHub] Rayfield window OK (toggle: RightShift)")
            else
                guiLastErr = tostring(win)
                warn("[SpermaHub] Rayfield CreateWindow fail: " .. tostring(win))
                RayLib = nil
            end
        end
    end

    if not RayLib and not LinLib then
        warn("[SpermaHub] GUI: оба движка не завелись — " .. tostring(guiLastErr))
        task.delay(3, function()
            pcall(function() toastImpl("GUI", "Меню не создаётся: " .. tostring(guiLastErr):sub(1, 100)) end)
        end)
    end
end

-- RightShift = скрыть/показать меню (какой бы движок ни жив)
S.rsToggleConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if LinLib and LinWindow then
            pcall(function() LinLib:Toggle() end)
        else
            local heirsR = { LP.PlayerGui }
            pcall(function() if gethui then table.insert(heirsR, gethui()) end end)
            pcall(function() table.insert(heirsR, game.CoreGui) end)
            for _, parent in ipairs(heirsR) do
                pcall(function()
                    local rf = parent:FindFirstChild("Rayfield")
                    if rf then rf.Enabled = not rf.Enabled end
                end)
            end
        end
    end
end)


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
-- ============ ANTI-AIM (ENI Suite: Spin / Jitter / Desync / Random + Fake Visualize) ============
local aaState = {CurrentAngle = 0, LastTick = tick(), FakeCharacter = nil}

local function aaGetRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function aaCreateFake()
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

local function aaDestroyFake()
    if aaState.FakeCharacter then
        pcall(function() aaState.FakeCharacter:Destroy() end)
        aaState.FakeCharacter = nil
    end
end

-- фейковое тело показывает, куда "смотрит" подменённый рут
local function aaUpdateFake(angle)
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

local function enableAntiAim()
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

local function disableAntiAim()
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
local function applyWalkSpeed()
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
local AR_STATES = {
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

bootStep("Watermark OK")

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- ============================================================
-- ============ GUI MODE: Voidware (дефолт) или WindUI ========
-- ============================================================
-- ---------- ТЕМА (как на референсе) ----------
local CT = {
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
local function cleanText(s)
    return (tostring(s):gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", ""))
end

local function cgNew(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do pcall(function() obj[k] = v end) end
    obj.Parent = parent
    return obj
end
local function cgCorner(r, parent)
    cgNew("UICorner", {CornerRadius = UDim.new(0, r or 4)}, parent)
end
local function listLayout(parent, pad, order)
    local l = cgNew("UIListLayout", {
        Padding = UDim.new(0, pad or 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
    return l
end

-- ---------- ТОСТЫ (свои, без сторонних либ) ----------
local ToastHolder = nil
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

local function cgToastDismiss(frame)
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
local Cfg = {}

-- ---------- КОРЕНЬ GUI ----------
-- Voidware-шелл УДАЛЁН НАСОВСЕМ (WindUI — единственная оболочка)
local CGGui = { Enabled = false } -- стаб: Unload/Enabled-ссылки не упадут
local CG_OPEN = false

local MODULES = {} -- все модули

-- ---------- КАТЕГОРИЯ → панель ----------
local CAT_ORDER = { Combat=1, Movement=2, Visuals=3, Player=4, Server=5, Miscellaneous=6 }
local curModule = nil

local function addCategoryImpl(title)
    return {key = title, scroll = nil} -- категории-вкладки создаёт renderGUI (Rayfield)
end

local function updModHeader(m) end

local function addPageImpl(cat, icon, title)
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

local function addPanelImpl(col, title)
    local sec = {title = cleanText(title), module = col.__module, __module = col.__module}
    table.insert(col.__module.elements, {kind = "section", title = sec.title})
    return sec
end

local function selectCategory(_) end
local function selectPage(_) end

-- ---------- ЭЛЕМЕНТЫ (capture; рисуем лениво) ----------
local keyCaptureEl = nil
-- список игроков — capture; рендерится при открытии настроек модуля
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
local function uiCall(kind, label, f, ...)
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

local dummyCtl
do
    local t = setmetatable({}, {
        __index = function() return function() end end,
    })
    dummyCtl = {
        sec = t, holder = nil,
        col1 = nil, col2 = nil, __module = nil,
    }
end

local function addCategory(title)
    return uiCall("addCategory", title, addCategoryImpl, title)
end

local function addPage(cat, icon, title)
    local r = uiCall("addPage", tostring(cat) .. "." .. tostring(title), addPageImpl, cat, icon, title)
    if r == nil then
        local m = {cat = cat, title = tostring(title), elements = {}, enableKey = nil,
                   bodyBuilt = false, open = false}
        curModule = m
        return {__module = m, col1 = {__module = m}, col2 = {__module = m}}
    end
    return r
end

local HOIST_CATS = { Combat = true, Movement = true, Visuals = true }
-- эти панели НЕ вытаскивать отдельными строками — они остаются внутри своего модуля
local NON_HOIST = { ["Target"] = true, ["Info"] = true, ["Silent Aura (1.8 Arena)"] = true, ["Mode Settings"] = true }
local function addPanel(col, title)
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

local function addToggle(panel, key, label, default, cb)
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

local function addSlider(panel, key, label, minV, maxV, default, step, cb)
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

local function addDropdown(panel, key, label, options, default, cb)
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

local function addKeybind(panel, key, label, defaultName, cb)
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

local function addButton(panel, label, cb, color, hover)
    return uiCall("addButton", label, function()
        local m = panel.__module
        table.insert(m.elements, {kind = "button", label = cleanText(label), cb = cb, module = m})
    end)
end

local function addText(panel, text)
    return uiCall("addText", tostring(text):sub(1, 32), function()
        local m = panel.__module
        table.insert(m.elements, {kind = "text", text = cleanText(text)})
    end)
end

local function addBindRow(panel, entry)
    return uiCall("addBindRow", tostring(entry.label), function()
        local m = panel.__module
        table.insert(m.elements, {kind = "bindrow", entry = entry})
    end)
end

local function makePlayerList(panel, height)
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
local doLoad, flingListCtl, killListCtl, specListCtl, tpListCtl
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
    addText(pTgt, "Пульсирующая подсветка цели Aimbot / Silent Aim.")
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

    local pJp = addPanel(pg.col1, "JumpPower")
    addToggle(pJp, "jp.enabled", "Enabled", false, function(state)
        S.jumpPowerOn = state
        if state then applyJumpPower() end
    end)
    addSlider(pJp, "jp.power", "Power", 50, 500, 50, 5, function(v)
        S.jumpPower = math.floor(v)
        if S.jumpPowerOn then applyJumpPower() end
    end)
    addText(pJp, "Сила прыжка (UseJumpPower). 50 — стандарт.")

    local pRagdoll = addPanel(pg.col1, "Anti Ragdoll")
    addToggle(pRagdoll, "player.antiragdoll", "Enabled", false, function(state)
        S.antiRagdoll = state
        toastImpl("Anti Ragdoll", state and "ON" or "OFF")
    end)
    addText(pRagdoll, "Не даёт упасть в ragdoll: при любом падении/физике мгновенно встаёт (GettingUp). Двигаться можно как обычно.")

    local pMorph = addPanel(pg.col2, "Appearance (Fake)")
    addButton(pMorph, "Fake Korblox", function() applyFakeKorblox() end)
    addButton(pMorph, "Fake Headless", function() applyFakeHeadless() end)
    addText(pMorph, "Визуальные морфы: Korblox-нога и Headless-голова (локально).")

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

bootStep("страницы OK")
-- ============================================================
-- ===================== ПОЛНАЯ ВЫГРУЗКА ======================
-- ============================================================
function fullCleanupNL()
    -- 1) снести окна ОБОИХ движков + свои GUI (по всем контейнерам)
    pcall(function()
        if LinLib and LinLib.Unload then LinLib:Unload() end
    end)
    pcall(function()
        local heirsR = {}
        table.insert(heirsR, LP.PlayerGui)
        pcall(function() if gethui then table.insert(heirsR, gethui()) end end)
        pcall(function() table.insert(heirsR, game:GetService("CoreGui")) end)
        for _, parent in ipairs(heirsR) do
            for _, gname in ipairs({"Rayfield", "SpermaLinoria", "SpermaAdmin", "SpermaKeySystem"}) do
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
    dcc(S.espConn)
    dcc(S.targetEspConn)
    dcc(S.wsConn)
    dcc(S.arConn)
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
    pcall(disableESP)
    pcall(disableTargetESP)
    local heirsT = { LP.PlayerGui }
    pcall(function() if gethui then table.insert(heirsT, gethui()) end end)
    pcall(function() table.insert(heirsT, game:GetService("CoreGui")) end)
    for _, parent in ipairs(heirsT) do
        for _, n in ipairs({
            "SpermaHubESP","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL",
            "SpermaHubNLToggle","SpermaHubClickGui","SpermaHubSpec","SpermaHubWatermark",
            "SpermaHubBinds","SpermaHubTHud","SpermaHubToast","SpermaHubBoot",
            "SpermaKeySystem","SpermaAdmin","Rayfield","SpermaLinoria","KeyUI","SpermaHubErrToast"
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
-- ============ WINDUI RENDERER (альтернативная оболочка) =====
-- ============================================================
-- wiring собирает ВСЕ элементы в m.elements — оболочки делят один источник данных
-- ---------- TOASTS → Rayfield Notify ----------
local function rayToastOverride()
    local oldToast = toastImpl
    toastImpl = function(title, msg)
        local t, text = tostring(title or ""), tostring(msg or "")
        local ok = pcall(function()
            RayLib:Notify({ Title = (t ~= "" and t or "SpermaHub"), Content = (text ~= "" and text or t), Duration = 2.6, Image = 4483362458 })
        end)
        if not ok then pcall(oldToast, title, msg) end
        print(("[SpermaHub] %s"):format((t ~= "" and (text ~= "" and (t .. " — " .. text) or t) or text)))
    end
end

local function renderGUI()
    if not (RayLib and RayWindow) then return end
    rayToastOverride()

    local tabs = {}
    local function getTab(cat)
        if tabs[cat] then return tabs[cat] end
        local ok, tab = pcall(function()
            return RayWindow:CreateTab(tostring(cat), 4483362458)
        end)
        if not ok or not tab then
            ok, tab = pcall(function() return RayWindow:CreateTab(tostring(cat)) end)
        end
        if not ok then
            warn(("[SpermaHub] Rayfield tab fail '%s': %s"):format(tostring(cat), tostring(tab)))
            tab = nil
        end
        tabs[cat] = tab
        return tab
    end

    print(("[SpermaHub] rayfield render: модулей в регистре: %d"):format(#MODULES))
    local rendered = 0
    for _, m in ipairs(MODULES) do
        if #m.elements > 0 then
            local tab = getTab(m.cat)
            if tab then
                local okSec, errSec = pcall(function()
                    tab:CreateSection(m.title)
                    if m.enableKey and Cfg[m.enableKey] then
                        local ek = m.enableKey
                        tab:CreateToggle({
                            Name = "Enabled",
                            CurrentValue = false,
                            Callback = function(st)
                                pcall(function() Cfg[ek].set(st == true) end)
                            end,
                        })
                    end
                    for _, el in ipairs(m.elements) do
                        local _el = el
                        pcall(function()
                            if _el.kind == "section" then
                                tab:CreateSection(_el.title)
                            elseif _el.kind == "toggle" then
                                local w = tab:CreateToggle({
                                    Name = _el.label,
                                    CurrentValue = _el.value == true,
                                    Callback = function(v)
                                        _el.value = (v == true)
                                        pcall(function() _el.cb(_el.value) end)
                                    end,
                                })
                                _el._upd = function() pcall(function() w:Set(_el.value == true) end) end
                            elseif _el.kind == "slider" then
                                local w = tab:CreateSlider({
                                    Name = _el.label,
                                    Range = { _el.min, _el.max },
                                    Increment = _el.step or 1,
                                    Suffix = "",
                                    CurrentValue = _el.value,
                                    Callback = function(v)
                                        v = tonumber(v) or _el.value
                                        _el.value = v
                                        pcall(function() _el.cb(v) end)
                                    end,
                                })
                                _el._upd = function() pcall(function() w:Set(_el.value) end) end
                            elseif _el.kind == "dropdown" then
                                local w = tab:CreateDropdown({
                                    Name = _el.label,
                                    Options = _el.options or {},
                                    CurrentOption = _el.value,
                                    MultipleOptions = false,
                                    Callback = function(v)
                                        if type(v) == "table" then v = v.Title or v.Value or v[1] end
                                        v = tostring(v)
                                        _el.value = v
                                        pcall(function() _el.cb(v) end)
                                    end,
                                })
                                _el._upd = function() pcall(function() if w.Refresh then w:Refresh(_el.options or {}, _el.value) end end) end
                            elseif _el.kind == "keybind" then
                                local cur = (_el.value and _el.value.Name) or "None"
                                local w = tab:CreateKeybind({
                                    Name = _el.label,
                                    CurrentKeybind = cur,
                                    HoldToInteract = false,
                                    Callback = function(v)
                                        local kc = nil
                                        pcall(function() kc = Enum.KeyCode[tostring(v)] end)
                                        if kc then
                                            _el.value = kc
                                            pcall(function() _el.cb(kc) end)
                                        end
                                    end,
                                })
                                _el._upd = function() pcall(function() if w.Set then w:Set((_el.value and _el.value.Name) or "None") end end) end
                            elseif _el.kind == "button" then
                                tab:CreateButton({
                                    Name = _el.label,
                                    Callback = function() pcall(function() _el.cb() end) end,
                                })
                            elseif _el.kind == "text" then
                                tab:CreateParagraph({ Title = _el.text, Content = " " })
                            elseif _el.kind == "bindrow" then
                                local entry = _el.entry
                                local cur = (entry.key and entry.key.Name) or "None"
                                tab:CreateKeybind({
                                    Name = entry.label,
                                    CurrentKeybind = cur,
                                    HoldToInteract = false,
                                    Callback = function(v)
                                        pcall(function() entry.key = Enum.KeyCode[tostring(v)] end)
                                        if BindRowRefs and BindRowRefs[entry] then pcall(BindRowRefs[entry]) end
                                    end,
                                })
                            elseif _el.kind == "plist" then
                                local names = {}
                                for _, d in ipairs(_el.data or {}) do table.insert(names, d.name) end
                                local w = tab:CreateDropdown({
                                    Name = "Выбор игрока",
                                    Options = (#names > 0 and names or { "---" }),
                                    CurrentOption = _el.selected,
                                    MultipleOptions = false,
                                    Callback = function(v)
                                        if type(v) == "table" then v = v.Title or v.Value or v[1] end
                                        if v == "" or v == "---" then v = nil end
                                        _el.selected = v
                                        if _el.onConnect then pcall(_el.onConnect, v) end
                                    end,
                                })
                                _el._paint = function()
                                    local ns = {}
                                    for _, d in ipairs(_el.data or {}) do table.insert(ns, d.name) end
                                    pcall(function() if w.Refresh then w:Refresh((#ns > 0 and ns or { "---" }), _el.selected) end end)
                                end
                            end
                        end)
                    end
                end)
                if not okSec then
                    warn(("[SpermaHub] Rayfield section fail '%s': %s"):format(tostring(m.title), tostring(errSec)))
                else
                    rendered = rendered + 1
                end
            end
        end
    end
    print(("[SpermaHub] Rayfield render готов: %d секций"):format(rendered))
end


-- ---------- TOASTS → Linoria Notify ----------
local function linToastOverride()
    local oldToast = toastImpl
    toastImpl = function(title, msg)
        local t, text = tostring(title or ""), tostring(msg or "")
        local ok = pcall(function()
            LinLib:Notify((t ~= "" and t or "SpermaHub") .. (text ~= "" and (": " .. text) or ""), 3)
        end)
        if not ok then pcall(oldToast, title, msg) end
        print(("[SpermaHub] %s"):format((t ~= "" and (text ~= "" and (t .. " — " .. text) or t) or text)))
    end
end

local function renderLinGUI()
    if not (LinLib and LinWindow) then return end
    linToastOverride()

    local tabs = {}
    local function getTab(cat)
        if tabs[cat] then return tabs[cat] end
        local ok, tab = pcall(function() return LinWindow:AddTab(tostring(cat)) end)
        if not ok or not tab then
            warn(("[SpermaHub] Linoria tab fail '%s': %s"):format(tostring(cat), tostring(tab)))
            tab = nil
        end
        tabs[cat] = tab
        return tab
    end

    local uidc = 0
    local function uid() uidc = uidc + 1 return "sh" .. uidc end

    print(("[SpermaHub] linoria render: модулей в регистре: %d"):format(#MODULES))
    local rendered = 0
    for _, m in ipairs(MODULES) do
        if #m.elements > 0 then
            local tab = getTab(m.cat)
            if tab then
                local okSec, errSec = pcall(function()
                    local group = tab:AddLeftGroupbox(m.title)
                    if m.enableKey and Cfg[m.enableKey] then
                        local ek = m.enableKey
                        group:AddToggle(uid(), {
                            Text = "Enabled",
                            Default = false,
                            Callback = function(st)
                                pcall(function() Cfg[ek].set(st == true) end)
                            end,
                        })
                    end
                    for _, el in ipairs(m.elements) do
                        local _el = el
                        pcall(function()
                            if _el.kind == "section" then
                                group:AddLabel("— " .. tostring(_el.title) .. " —")
                            elseif _el.kind == "toggle" then
                                local id = uid()
                                group:AddToggle(id, {
                                    Text = _el.label,
                                    Default = _el.value == true,
                                    Callback = function(v)
                                        _el.value = (v == true)
                                        pcall(function() _el.cb(_el.value) end)
                                    end,
                                })
                                _el._upd = function()
                                    pcall(function()
                                        local tg = LinLib.Toggles[id]
                                        if tg then tg:SetValue(_el.value == true) end
                                    end)
                                end
                            elseif _el.kind == "slider" then
                                local id = uid()
                                local st = _el.step or 1
                                local rd = (st % 1 == 0) and 0 or 1
                                group:AddSlider(id, {
                                    Text = _el.label,
                                    Default = _el.value,
                                    Min = _el.min,
                                    Max = (_el.max == _el.min and (_el.min + 1) or _el.max),
                                    Rounding = rd,
                                    Callback = function(v)
                                        v = tonumber(v) or _el.value
                                        _el.value = v
                                        pcall(function() _el.cb(v) end)
                                    end,
                                })
                                _el._upd = function()
                                    pcall(function()
                                        local op = LinLib.Options[id]
                                        if op then op:SetValue(_el.value) end
                                    end)
                                end
                            elseif _el.kind == "dropdown" then
                                local id = uid()
                                local opts = _el.options or {}
                                if #opts == 0 then opts = { "---" } end
                                local defIdx = 1
                                for i, o in ipairs(opts) do
                                    if o == _el.value then defIdx = i break end
                                end
                                group:AddDropdown(id, {
                                    Text = _el.label,
                                    Values = opts,
                                    Default = defIdx,
                                    Multi = false,
                                    Callback = function(v)
                                        if type(v) == "table" then v = v[1] end
                                        v = tostring(v)
                                        _el.value = v
                                        pcall(function() _el.cb(v) end)
                                    end,
                                })
                                _el._upd = function()
                                    pcall(function()
                                        local op = LinLib.Options[id]
                                        if op then
                                            local os2 = _el.options or {}
                                            if #os2 == 0 then os2 = { "---" } end
                                            op:SetValues(os2)
                                        end
                                    end)
                                end
                            elseif _el.kind == "keybind" then
                                local id = uid()
                                local cur = (_el.value and _el.value.Name) or "None"
                                local lab = group:AddLabel(_el.label)
                                pcall(function()
                                    lab:AddKeyPicker(id, {
                                        Default = (cur ~= "None" and cur or "M"),
                                        Mode = "Hold",
                                        Text = _el.label,
                                        ChangedCallback = function(v)
                                            local kc = nil
                                            pcall(function() kc = Enum.KeyCode[tostring(v)] end)
                                            if kc then
                                                _el.value = kc
                                                pcall(function() _el.cb(kc) end)
                                            end
                                        end,
                                    })
                                end)
                            elseif _el.kind == "button" then
                                group:AddButton({
                                    Text = _el.label,
                                    Func = function() pcall(function() _el.cb() end) end,
                                })
                            elseif _el.kind == "text" then
                                group:AddLabel(tostring(_el.text))
                            elseif _el.kind == "bindrow" then
                                local entry = _el.entry
                                local id = uid()
                                local cur = (entry.key and entry.key.Name) or "None"
                                local lab = group:AddLabel(tostring(entry.label))
                                pcall(function()
                                    lab:AddKeyPicker(id, {
                                        Default = (cur ~= "None" and cur or "M"),
                                        Mode = "Hold",
                                        Text = tostring(entry.label),
                                        ChangedCallback = function(v)
                                            pcall(function() entry.key = Enum.KeyCode[tostring(v)] end)
                                            if BindRowRefs and BindRowRefs[entry] then pcall(BindRowRefs[entry]) end
                                        end,
                                    })
                                end)
                            elseif _el.kind == "plist" then
                                local id = uid()
                                local names = {}
                                for _, d in ipairs(_el.data or {}) do table.insert(names, d.name) end
                                if #names == 0 then names = { "---" } end
                                group:AddDropdown(id, {
                                    Text = "Выбор игрока",
                                    Values = names,
                                    Default = 1,
                                    Multi = false,
                                    Callback = function(v)
                                        if type(v) == "table" then v = v[1] end
                                        if v == "---" then v = nil end
                                        _el.selected = v
                                        if _el.onConnect then pcall(_el.onConnect, v) end
                                    end,
                                })
                                _el._paint = function()
                                    local ns = {}
                                    for _, d in ipairs(_el.data or {}) do table.insert(ns, d.name) end
                                    if #ns == 0 then ns = { "---" } end
                                    pcall(function()
                                        local op = LinLib.Options[id]
                                        if op then op:SetValues(ns) end
                                    end)
                                end
                            end
                        end)
                    end
                end)
                if not okSec then
                    warn(("[SpermaHub] Linoria section fail '%s': %s"):format(tostring(m.title), tostring(errSec)))
                else
                    rendered = rendered + 1
                end
            end
        end
    end
    print(("[SpermaHub] Linoria render готов: %d секций"):format(rendered))
    pcall(function()
        if LinLib and LinWindow then LinLib:Toggle() end
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
local okR, errR = pcall(function()
    if RayWindow then
        renderGUI()
    elseif LinWindow then
        renderLinGUI()
    end
end)
if not okR then warn("[SpermaHub] GUI render crash: " .. tostring(errR)) end
print("[SpermaHub] gui: рендер завершён")

toastImpl("SpermaHub", "SpermaHub загружен!")
print("✦ SpermaHub загружен!")
print("Combat: Legitbot | Hitbox | Kill | Fling | Spectate | Anti-Aim | AutoClicker + AntiFling/AutoStrafe")
print("Visuals + Movement + Player + Server (Bypass/Server) | Misc")
