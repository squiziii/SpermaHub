--=================================================================
--  SPERMAHUB UI  (Neverlose-style, Roblox, standalone)
--=================================================================
--  Никаких внешних библиотек. Всё на голых Instance.
--
--  API:
--    getgenv().SpermaHubUI.Config          -- все значения
--    getgenv().SpermaHubUI.Notify(text)    -- тост
--    getgenv().SpermaHubUI.Save()          -- сохранить в spermahub_config.json
--    getgenv().SpermaHubUI.Unload()        -- выгрузить
--    getgenv().SpermaHubUI.Icons           -- таблица иконок (glyph / image)
--    getgenv().SpermaHubUI.SetIcon(name, { image = "rbxassetid://..." })
--    getgenv().SpermaHubUI.RefreshIcons()  -- перерисовать все иконки
--    getgenv().SpermaHubUI.Features        -- состояние функций хаба
----
--  Показать/скрыть: RightShift (или Escape - закрыть)
--=================================================================

local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Tween     = game:GetService("TweenService")
local Lighting  = game:GetService("Lighting")
local Http      = game:GetService("HttpService")
local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

--=================================================================
--  КОНСТАНТЫ / ПАЛИТРА
--=================================================================
local W, H      = 1120, 800
local SB        = 272          -- ширина сайдбара
local HEADER    = 98           -- высота шапки

local C = {
    panel     = Color3.fromRGB(8, 11, 17),
    sidebar   = Color3.fromRGB(10, 13, 20),
    card      = Color3.fromRGB(12, 17, 25),
    input     = Color3.fromRGB(8, 12, 18),
    track     = Color3.fromRGB(35, 40, 50),
    line      = Color3.fromRGB(26, 35, 47),
    cardLine  = Color3.fromRGB(23, 48, 63),
    accent    = Color3.fromRGB(42, 156, 219),
    accentDim = Color3.fromRGB(24, 78, 108),
    text      = Color3.fromRGB(233, 236, 241),
    label     = Color3.fromRGB(211, 218, 228),
    dim       = Color3.fromRGB(124, 135, 150),
    faint     = Color3.fromRGB(86, 95, 110),
    knob      = Color3.fromRGB(212, 219, 230),
}

local F = {
    reg   = Enum.Font.Gotham,
    med   = Enum.Font.GothamMedium,
    bold  = Enum.Font.GothamBold,
    black = Enum.Font.GothamBlack,
}

local CFG = {}   -- page/card/element -> value

--=================================================================
--  ХЕЛПЕРЫ
--=================================================================
local function new(class, props, parent)
    local obj = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                pcall(function() obj[k] = v end)
            end
        end
    end
    if parent then obj.Parent = parent end
    return obj
end

local function corner(parent, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function stroke(parent, color, transparency, thickness)
    return new("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function txt(parent, text, props)
    local base = {
        BackgroundTransparency = 1,
        Text = text,
        Font = F.med,
        TextSize = 16,
        TextColor3 = C.label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }
    for k, v in pairs(props or {}) do base[k] = v end
    return new("TextLabel", base, parent)
end

local function counter()
    local n = 0
    return function()
        n = n + 1
        return n
    end
end

local function fmtNumber(v, decimals)
    if (decimals or 0) <= 0 then
        return tostring(math.floor(v + 0.5))
    end
    return string.format("%." .. decimals .. "f", v)
end

--=================================================================
--  ИКОНКИ  (единый источник правды)
--=================================================================
--  Запись: { glyph = "символ", image = "rbxassetid://..." }.
--    image  — если задан (строка или голый числовой id), рисуется картинка,
--             глиф игнорируется. Цвет картинки берётся из цвета слота.
--    glyph  — текстовый символ; используется, когда image = nil.
--
--  Подмена на ходу:
--    getgenv().SpermaHubUI.SetIcon("weapon", { image = "rbxassetid://1234567890" })
--    getgenv().SpermaHubUI.Icons.weapon.image = 1234567890
--    getgenv().SpermaHubUI.RefreshIcons()
--
--  Глифы оставлены только из блоков, которые есть почти в любом шрифте Roblox:
--  Basic Latin / Latin-1 / General Punctuation / Geometric Shapes (U+25xx).
--  Всё, что могло улететь в эмодзи или квадратик (⚔ ⚙ ⌖ ↺ ⌸ ✹ ⌕ ◍ ⚇ ◫ ⌄ ❐ ✛),
--  заменено. Поиск рисуется примитивами (см. magnifier), т.к. ⌕ ненадёжен.
--=================================================================
local ICONS = {
    -- сайдбар
    ragebot   = { glyph = "\u{25C6}" },        -- ◆   было ⌖ U+2316
    antiaim   = { glyph = "\u{25CB}" },        -- ○   было ↺ U+21BA
    legitbot  = { glyph = "\u{25C9}" },        -- ◉   было ◉ (оставлено)
    players   = { glyph = "\u{25A0}" },        -- ■   было ⚇ U+2687
    weapon    = { glyph = "\u{25B2}" },        -- ▲   было ⚔ U+2694
    grenades  = { glyph = "\u{25BC}" },        -- ▼   было ◍ U+25CD
    bomb      = { glyph = "\u{25C7}" },        -- ◇   было ✹ U+2739
    world     = { glyph = "\u{25CE}" },        -- ◎   (оставлено)
    view      = { glyph = "\u{25A1}" },        -- □   было ◫ U+25EB
    main      = { glyph = "\u{25CF}" },        -- ●   было ✛ U+271B
    inventory = { glyph = "\u{25AA}" },        -- ▪   было ⌸ U+2338
    scripts   = { glyph = "</>" },             -- ASCII, безопасно
    configs   = { glyph = "\u{25A4}" },        -- ▤   было ⚙ U+2699

    -- шапка и контролы
    save      = { glyph = "\u{25A0}" },        -- ■   было ❐ U+2750
    search    = { glyph = nil },               -- рисуется примитивами (magnifier)
    gear      = { glyph = "\u{2022}\u{2022}\u{2022}" }, -- •••  было ⚙ U+2699
    eye       = { glyph = "\u{25C9}" },        -- ◉
    arrow     = { glyph = "\u{25BE}" },        -- ▾   было ⌄ U+2304
}

local iconSlots = {}

-- строка "rbxassetid://..." из def.image (принимает и голый числовой id)
local function iconSrc(def)
    local img = def.image
    if type(img) == "number" then
        return "rbxassetid://" .. tostring(img)
    end
    if type(img) == "string" and img ~= "" then
        if tonumber(img) then
            return "rbxassetid://" .. img
        end
        return img
    end
    return nil
end

local function drawIcon(slot)
    local def = ICONS[slot.name] or {}
    if slot.drawn then
        for _, obj in ipairs(slot.drawn) do
            pcall(function() obj:Destroy() end)
        end
        slot.drawn = nil
    end

    local src = iconSrc(def)
    if src then
        slot.image.Image = src
        slot.image.Visible = true
        slot.label.Visible = false
    elseif def.glyph and def.glyph ~= "" then
        slot.image.Visible = false
        slot.label.Visible = true
        slot.label.Text = def.glyph
    else
        slot.image.Visible = false
        slot.label.Visible = false
        if slot.builtin then
            slot.drawn = slot.builtin(slot.holder, slot.label.TextColor3)
        end
    end
end

-- слот иконки: держатель + текстовый глиф + ImageLabel под asset id
local function iconSlot(parent, name, cfg)
    cfg = cfg or {}
    local holder = new("Frame", {
        AnchorPoint = cfg.anchor,
        Position = cfg.position,
        Size = cfg.size or UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = cfg.zIndex or 1,
    }, parent)

    local color = cfg.color or C.dim
    local label = txt(holder, "", {
        Size = UDim2.fromScale(1, 1),
        TextSize = cfg.textSize or 20,
        Font = cfg.font or F.bold,
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = cfg.zIndex or 1,
    })

    local side = cfg.imageSize or ((cfg.textSize or 20) + 2)
    local image = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(side, side),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = color,
        ScaleType = Enum.ScaleType.Fit,
        Visible = false,
        ZIndex = cfg.zIndex or 1,
    }, holder)

    local slot = { name = name, holder = holder, label = label, image = image, builtin = cfg.builtin }
    table.insert(iconSlots, slot)
    drawIcon(slot)
    return slot
end

local function iconTint(slot, color)
    if not slot then return end
    slot.label.TextColor3 = color
    slot.image.ImageColor3 = color
end

local function refreshIcons()
    for _, slot in ipairs(iconSlots) do
        drawIcon(slot)
    end
end

local function setIcon(name, def)
    ICONS[name] = def or { glyph = "?" }
    for _, slot in ipairs(iconSlots) do
        if slot.name == name then drawIcon(slot) end
    end
end

-- лупа из примитивов: замена глифа ⌕
local function magnifier(holder, color)
    local lens = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -2, 0.5, -2),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, holder)
    corner(lens, 6)
    local ring = stroke(lens, color, 0, 1.6)
    local handle = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 5, 0.5, 5),
        Size = UDim2.fromOffset(8, 1.6),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Rotation = 45,
    }, holder)
    return { lens, ring, handle }
end

--=================================================================
--  КОРЕНЬ
--=================================================================
if getgenv and getgenv().SpermaHubUI and getgenv().SpermaHubUI.Unload then
    pcall(function() getgenv().SpermaHubUI.Unload() end)
end
if getgenv and getgenv().NeverloseUI and getgenv().NeverloseUI.Unload then
    pcall(function() getgenv().NeverloseUI.Unload() end)
end

local gui = new("ScreenGui", {
    Name = "SpermaHubUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 990,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local backdrop = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    Active = true,
}, gui)

local panel = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(panel, 8)
stroke(panel, C.line, 0.15)

local scale = new("UIScale", {Scale = 1}, panel)

local function fitScale()
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
    local s = math.min(vp.X / (W + 80), vp.Y / (H + 80))
    scale.Scale = math.clamp(s, 0.4, 1.15)
end
fitScale()

local camConn
local function hookCamera()
    if camConn then
        pcall(function() camConn:Disconnect() end)
        camConn = nil
    end
    local cam = workspace.CurrentCamera
    if cam and cam.GetPropertyChangedSignal then
        pcall(function()
            camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
        end)
    end
end
task.spawn(hookCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    fitScale()
    hookCamera()
end)

local blur = Instance.new("BlurEffect")
blur.Size = 14
blur.Parent = Lighting

--=================================================================
--  САЙДБАР
--=================================================================
local sidebar = new("Frame", {
    Size = UDim2.new(0, SB, 1, 0),
    BackgroundColor3 = C.sidebar,
    BorderSizePixel = 0,
}, panel)
new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(13, 17, 26), Color3.fromRGB(7, 10, 15)),
    Rotation = 90,
}, sidebar)

-- лого
local logo = txt(sidebar, "SPERMAHUB", {
    Position = UDim2.new(0, 26, 0, 24),
    Size = UDim2.new(1, -52, 0, 46),
    Font = F.black,
    TextSize = 30,
    TextColor3 = Color3.fromRGB(240, 243, 248),
})

-- вертикальная линия между сайдбаром и контентом
new("Frame", {
    Position = UDim2.new(0, SB, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = C.line,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
}, panel)

local nav = new("ScrollingFrame", {
    Position = UDim2.new(0, 14, 0, 92),
    Size = UDim2.new(1, -28, 1, -102),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = C.accentDim,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollingEnabled = true,
}, sidebar)
new("UIListLayout", {
    Padding = UDim.new(0, 2),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, nav)

local navOrd = counter()
local navGroups = {}

local function addGroup(title)
    local order = navOrd()
    local spacer = new("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, nav)
    local lbl = txt(nav, title, {
        Size = UDim2.new(1, 0, 0, 22),
        TextSize = 15,
        Font = F.med,
        TextColor3 = C.faint,
        LayoutOrder = navOrd(),
    })
    new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, lbl)

    local g = {label = lbl, spacer = spacer, items = {}}
    table.insert(navGroups, g)
    return g
end

local function buildNavItem(group, def)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Color3.fromRGB(18, 36, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        LayoutOrder = navOrd(),
    }, nav)
    corner(btn, 6)
    local st = stroke(btn, C.accentDim, 1, 1)

    local icon = iconSlot(btn, def.icon, {
        size = UDim2.new(0, 46, 1, 0),
        textSize = 21,
        font = F.bold,
        color = C.accent,
    })
    local name = txt(btn, def.name, {
        Position = UDim2.new(0, 46, 0, 0),
        Size = UDim2.new(1, -56, 1, 0),
        TextSize = 17,
        Font = F.med,
        TextColor3 = C.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    btn.MouseEnter:Connect(function()
        if def.selected then return end
        Tween:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.9}):Play()
        name.TextColor3 = C.label
    end)
    btn.MouseLeave:Connect(function()
        if def.selected then return end
        Tween:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
        name.TextColor3 = C.dim
    end)

    def.btn = btn
    def.iconSlot = icon
    def.nameLbl = name
    def.navStroke = st
    table.insert(group.items, def)
    return def
end

--=================================================================
--  ШАПКА КОНТЕНТА
--=================================================================
local header = new("Frame", {
    Position = UDim2.new(0, SB, 0, 0),
    Size = UDim2.new(1, -SB, 0, HEADER),
    BackgroundTransparency = 1,
}, panel)

new("Frame", {
    Position = UDim2.new(0, 30, 0, HEADER - 1),
    Size = UDim2.new(1, -54, 0, 1),
    BackgroundColor3 = C.line,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
}, header)

local saveBtn = new("TextButton", {
    Position = UDim2.new(0, 32, 0, 30),
    Size = UDim2.fromOffset(148, 40),
    BackgroundColor3 = Color3.fromRGB(12, 17, 25),
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
}, header)
corner(saveBtn, 5)
stroke(saveBtn, C.line, 0.2)
iconSlot(saveBtn, "save", {
    position = UDim2.new(0, 16, 0, 0),
    size = UDim2.new(0, 20, 1, 0),
    textSize = 17,
    font = F.med,
    color = C.dim,
})
txt(saveBtn, "Save", {
    Position = UDim2.new(0, 44, 0, 0),
    Size = UDim2.new(1, -54, 1, 0),
    TextSize = 17,
    TextColor3 = C.text,
})

local searchBtn = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -30, 0, 34),
    Size = UDim2.fromOffset(30, 30),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
}, header)
iconSlot(searchBtn, "search", {
    color = C.text,
    builtin = magnifier,
})

local gearBtn = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -76, 0, 34),
    Size = UDim2.fromOffset(30, 30),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
}, header)
iconSlot(gearBtn, "gear", {
    textSize = 13,
    font = F.bold,
    color = C.text,
})

local searchBox = new("TextBox", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -116, 0, 32),
    Size = UDim2.fromOffset(210, 34),
    BackgroundColor3 = C.input,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Search",
    PlaceholderColor3 = C.faint,
    Font = F.med,
    TextSize = 15,
    TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Visible = false,
}, header)
corner(searchBox, 4)
stroke(searchBox, C.line, 0.2)
new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, searchBox)

--=================================================================
--  КОНТЕНТ (страницы)
--=================================================================
local body = new("Frame", {
    Position = UDim2.new(0, SB + 30, 0, HEADER),
    Size = UDim2.new(1, -(SB + 30) - 32, 1, -HEADER - 30),
    BackgroundTransparency = 1,
}, panel)

--=================================================================
--  ПОПАП (dropdown / меню)
--=================================================================
local popup, popupCatcher

local function closePopup()
    if popup then popup:Destroy() popup = nil end
    if popupCatcher then popupCatcher:Destroy() popupCatcher = nil end
end

local function openPopup(anchor, items, onPick, width)
    closePopup()

    popupCatcher = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 400,
    }, panel)
    popupCatcher.MouseButton1Click:Connect(closePopup)

    local s = math.max(0.01, scale.Scale)
    local ax = (anchor.AbsolutePosition.X - panel.AbsolutePosition.X) / s
    local ay = (anchor.AbsolutePosition.Y - panel.AbsolutePosition.Y) / s
    local aw = anchor.AbsoluteSize.X / s
    local ah = anchor.AbsoluteSize.Y / s

    width = math.max(120, width or aw)
    local px = math.clamp(ax + aw - width, 8, W - width - 8)

    local height = 10 + #items * 28
    popup = new("Frame", {
        Position = UDim2.fromOffset(px, ay + ah + 4),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = Color3.fromRGB(14, 19, 28),
        BorderSizePixel = 0,
        ZIndex = 401,
    }, panel)
    corner(popup, 5)
    stroke(popup, C.line, 0.1)
    new("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, popup)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 5),
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5),
    }, popup)

    for i, item in ipairs(items) do
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Color3.fromRGB(30, 48, 64),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 402,
        }, popup)
        corner(b, 4)
        txt(b, tostring(item), {
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -16, 1, 0),
            TextSize = 15,
            TextColor3 = C.label,
            ZIndex = 403,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.78 end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
        b.MouseButton1Click:Connect(function()
            closePopup()
            if onPick then onPick(item) end
        end)
    end
end

--=================================================================
--  ТОСТ
--=================================================================
local toast
local function notify(text)
    if toast then toast:Destroy() end
    toast = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -22),
        Size = UDim2.new(0, 0, 0, 36),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(16, 22, 32),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ZIndex = 450,
    }, panel)
    corner(toast, 6)
    stroke(toast, C.accentDim, 0.4)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 18),
        PaddingRight = UDim.new(0, 18),
    }, toast)
    local lbl = txt(toast, text, {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 15,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 451,
    })

    local this = toast
    task.delay(1.9, function()
        if not (this and this.Parent) then return end
        local ti = TweenInfo.new(0.35)
        Tween:Create(this, ti, {BackgroundTransparency = 1}):Play()
        Tween:Create(lbl, ti, {TextTransparency = 1}):Play()
        task.delay(0.45, function()
            if this and this.Parent then this:Destroy() end
            if toast == this then toast = nil end
        end)
    end)
end

--=================================================================
--  КОНТРОЛЫ
--=================================================================
local function buildToggle(parent, label, default, hasEye, key, onChange)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, parent)

    local lbl = txt(row, label, {
        Size = UDim2.new(0.62, 0, 1, 0),
        TextSize = 17,
        TextColor3 = C.label,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local eyeBtn, eyeIcon
    if hasEye then
        eyeBtn = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -58, 0.5, 0),
            Size = UDim2.fromOffset(24, 24),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 5,
        }, row)
        eyeIcon = iconSlot(eyeBtn, "eye", {
            textSize = 19,
            font = F.reg,
            color = C.dim,
            zIndex = 5,
            imageSize = 20,
        })
    end

    local track = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(44, 22),
        BackgroundColor3 = C.track,
        BorderSizePixel = 0,
    }, row)
    corner(track, 11)

    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = C.knob,
        BorderSizePixel = 0,
    }, track)
    corner(knob, 8)

    local hit = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(hasEye and 96 or 48, 32),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    }, row)

    local state = default and true or false

    local function paint()
        local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        Tween:Create(track, ti, {BackgroundColor3 = state and C.accent or C.track}):Play()
        Tween:Create(knob, ti, {
            Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        }):Play()
    end

    local function set(value, silent)
        state = value and true or false
        if key then CFG[key] = state end
        paint()
        if not silent and onChange then
            task.spawn(function()
                local ok, err = pcall(onChange, state)
                if not ok then warn("[SpermaHubUI] toggle callback: " .. tostring(err)) end
            end)
        end
    end

    if key then CFG[key] = state end
    paint()

    hit.MouseButton1Click:Connect(function() set(not state) end)

    if eyeBtn then
        local shown = true
        eyeBtn.MouseButton1Click:Connect(function()
            shown = not shown
            lbl.TextTransparency = shown and 0 or 0.55
            iconTint(eyeIcon, shown and C.dim or C.faint)
        end)
    end

    return {
        frame = row,
        set = set,
        get = function() return state end,
    }
end

local function buildSlider(parent, label, minV, maxV, default, step, key, onChange)
    step = step or 1
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
    }, parent)

    txt(row, label, {
        Size = UDim2.new(0, 174, 1, 0),
        TextSize = 17,
        TextColor3 = C.label,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local valBox = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(50, 25),
        BackgroundColor3 = C.input,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, row)
    corner(valBox, 3)
    stroke(valBox, C.line, 0.2)
    local valLbl = txt(valBox, "", {
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = 14,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local track = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 186, 0.5, 0),
        Size = UDim2.new(1, -186 - 62, 0, 4),
        BackgroundColor3 = Color3.fromRGB(28, 34, 44),
        BorderSizePixel = 0,
    }, row)
    corner(track, 2)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 2)

    local thumb = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(13, 13),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, track)
    corner(thumb, 7)

    local hit = new("TextButton", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 178, 0.5, 0),
        Size = UDim2.new(1, -178 - 58, 0, 26),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local decimals = 0
    do
        local s = step
        while s < 0.999 and decimals < 3 do
            s = s * 10
            decimals = decimals + 1
        end
    end

    local value = math.clamp(tonumber(default) or minV, minV, maxV)

    local function paint()
        local f = (value - minV) / math.max(1e-6, maxV - minV)
        fill.Size = UDim2.new(f, 0, 1, 0)
        thumb.Position = UDim2.new(f, 0, 0.5, 0)
        valLbl.Text = fmtNumber(value, decimals)
    end

    local function set(v, silent)
        value = math.clamp(tonumber(v) or value, minV, maxV)
        if decimals > 0 then
            local m = 10 ^ decimals
            value = math.floor(value * m + 0.5) / m
        else
            value = math.floor(value + 0.5)
        end
        if key then CFG[key] = value end
        paint()
        if not silent and onChange then
            task.spawn(function()
                local ok, err = pcall(onChange, value)
                if not ok then warn("[SpermaHubUI] slider callback: " .. tostring(err)) end
            end)
        end
    end

    local function applyFromX(x)
        local ax = track.AbsolutePosition.X
        local aw = math.max(1, track.AbsoluteSize.X)
        local f = math.clamp((x - ax) / aw, 0, 1)
        local raw = minV + (maxV - minV) * f
        local stepped = minV + math.floor((raw - minV) / step + 0.5) * step
        set(stepped)
    end

    local dragging = false
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            applyFromX(input.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            applyFromX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    if key then CFG[key] = value end
    paint()

    return {
        frame = row,
        set = set,
        get = function() return value end,
    }
end

local function buildDropdown(parent, label, options, default, hasEye, key, onChange)
    options = options or {}
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, parent)

    txt(row, label, {
        Size = UDim2.new(0.5, 0, 1, 0),
        TextSize = 17,
        TextColor3 = C.label,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    if hasEye then
        local eyeBtn = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -228, 0.5, 0),
            Size = UDim2.fromOffset(24, 24),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 5,
        }, row)
        iconSlot(eyeBtn, "eye", {
            textSize = 19,
            font = F.reg,
            color = C.dim,
            zIndex = 5,
            imageSize = 20,
        })
    end

    local box = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(200, 28),
        BackgroundColor3 = C.input,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(box, 4)
    stroke(box, C.line, 0.15)

    local value = tostring(default or options[1] or "")
    local valLbl = txt(box, value, {
        Position = UDim2.new(0, 9, 0, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextSize = 16,
        TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    iconSlot(box, "arrow", {
        anchor = Vector2.new(1, 0.5),
        position = UDim2.new(1, -8, 0.5, 0),
        size = UDim2.fromOffset(16, 16),
        textSize = 16,
        font = F.bold,
        color = C.dim,
        imageSize = 12,
    })

    local function set(v, silent)
        value = tostring(v)
        valLbl.Text = value
        if key then CFG[key] = value end
        if not silent and onChange then
            task.spawn(function()
                local ok, err = pcall(onChange, value)
                if not ok then warn("[SpermaHubUI] dropdown callback: " .. tostring(err)) end
            end)
        end
    end

    box.MouseButton1Click:Connect(function()
        openPopup(box, options, function(pick)
            set(pick)
        end)
    end)

    if key then CFG[key] = value end

    return {
        frame = row,
        set = set,
        get = function() return value end,
    }
end

local function buildLabel(parent, text)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, parent)
    txt(row, text, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextSize = 14,
        TextColor3 = C.faint,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    return {frame = row}
end

--=================================================================
--  КАРТОЧКА
--=================================================================
local function addCard(column, title, pageName)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
    }, column)
    corner(frame, 6)
    stroke(frame, C.line, 0.35)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 15),
        PaddingBottom = UDim.new(0, 16),
        PaddingLeft = UDim.new(0, 18),
        PaddingRight = UDim.new(0, 18),
    }, frame)
    new("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)

    local ord = counter()

    local head = new("Frame", {
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        LayoutOrder = ord(),
    }, frame)
    txt(head, title, {
        Size = UDim2.new(1, 0, 1, 0),
        Font = F.bold,
        TextSize = 19,
        TextColor3 = C.text,
    })

    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.cardLine,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        LayoutOrder = ord(),
    }, frame)

    local card = {}

    local function keyFor(label)
        return pageName .. "/" .. title .. "/" .. label
    end

    function card:toggle(label, default, hasEye, cb)
        local c = buildToggle(frame, label, default, hasEye, keyFor(label), cb)
        c.frame.LayoutOrder = ord()
        return c
    end

    function card:slider(label, minV, maxV, default, step, cb)
        local c = buildSlider(frame, label, minV, maxV, default, step, keyFor(label), cb)
        c.frame.LayoutOrder = ord()
        return c
    end

    function card:dropdown(label, options, default, hasEye, cb)
        local c = buildDropdown(frame, label, options, default, hasEye, keyFor(label), cb)
        c.frame.LayoutOrder = ord()
        return c
    end

    function card:text(value)
        local c = buildLabel(frame, value)
        c.frame.LayoutOrder = ord()
        return c
    end

    return card
end

--=================================================================
--  СТРАНИЦА
--=================================================================
local function createPage(def)
    local holder = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    }, body)

    local cols = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, holder)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 28),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, cols)

    local function column(order)
        local sf = new("ScrollingFrame", {
            Size = UDim2.new(0.5, -14, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.accentDim,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            LayoutOrder = order,
        }, cols)
        new("UIListLayout", {
            Padding = UDim.new(0, 26),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, sf)
        return sf
    end

    local left = column(1)
    local right = column(2)

    local page = {def = def, holder = holder, left = left, right = right}

    function page:card(title, side)
        local target = (side == "right") and right or left
        return addCard(target, title, def.name)
    end

    return page
end

--=================================================================
--  ФУНКЦИИ ХАБА
--=================================================================
--  Логика перенесена из sperma.lua (репозиторий): Aimbot, Silent Aim,
--  Hitbox Expander, ESP + скелет, Fly, Noclip, Click TP, WalkSpeed, Kill Player.
--=================================================================
local FZ = {
    aim     = { on = false, fov = 120, smooth = 0.3, conn = nil },
    silent  = { on = false, fov = 150, conn = nil },
    hitbox  = { on = false, size = 5, conn = nil, sizes = {} },
    esp     = { on = false, skel = true, conn = nil, gui = nil, objects = {}, skelFrames = {} },
    fly     = { on = false, speed = 50, conn = nil, bv = nil, bg = nil },
    noclip  = { on = false, conn = nil },
    clickTp = { on = false, height = 3, conn = nil },
    walk    = { on = false, speed = 16, conn = nil },
}

local function alive(plr)
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return ch:FindFirstChild("HumanoidRootPart") ~= nil
end

local function targetPart(ch)
    if not ch then return nil end
    return ch:FindFirstChild("Head") or ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
end

-- ближайший к центру экрана игрок в радиусе FOV (в пикселях)
local function findTarget(fov)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local best, bestDist = nil, fov
    local vp = cam.ViewportSize
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local ch = plr.Character
            if ch then
                local head = ch:FindFirstChild("Head")
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0 then
                    local sp, onScreen = cam:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local d = math.sqrt((sp.X - vp.X / 2) ^ 2 + (sp.Y - vp.Y / 2) ^ 2)
                        if d < bestDist then
                            bestDist = d
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end

--===================  AIMBOT  ===================
local function setAimbot(on)
    FZ.aim.on = on and true or false
    if FZ.aim.conn then
        pcall(function() FZ.aim.conn:Disconnect() end)
        FZ.aim.conn = nil
    end
    if not FZ.aim.on then return end
    FZ.aim.conn = RunService.RenderStepped:Connect(function()
        if not FZ.aim.on then return end
        local target = findTarget(FZ.aim.fov)
        local head = target and target.Character and target.Character:FindFirstChild("Head")
        local cam = workspace.CurrentCamera
        if head and cam then
            local lookAt = CFrame.new(cam.CFrame.Position, head.Position)
            cam.CFrame = cam.CFrame:Lerp(lookAt, FZ.aim.smooth)
        end
    end)
end

--===================  SILENT AIM  ===================
local function silentSupported()
    local hasHook, hasMeta, hasReadonly, hasClosure = false, false, false, false
    pcall(function() hasHook = type(hookfunction) == "function" end)
    pcall(function() hasMeta = type(getrawmetatable) == "function" end)
    pcall(function() hasReadonly = type(setreadonly) == "function" end)
    pcall(function() hasClosure = type(newcclosure) == "function" end)
    return hasHook and hasMeta and hasReadonly and hasClosure
end

local function setSilentAim(on)
    FZ.silent.on = on and true or false
    if FZ.silent.conn then
        pcall(function() FZ.silent.conn:Disconnect() end)
        FZ.silent.conn = nil
    end
    if not FZ.silent.on then return end

    if not silentSupported() then
        FZ.silent.on = false
        notify("Silent Aim: нет hookfunction")
        return
    end

    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        local oldIndex = mt.__index
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if FZ.silent.on and (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") then
                local target = findTarget(FZ.silent.fov)
                local part = target and targetPart(target.Character)
                if part then
                    local args = { ... }
                    if args[1] and args[1].Origin then
                        local origin = args[1].Origin
                        args[1] = Ray.new(origin, (part.Position - origin).Unit * 1000)
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
            return oldNamecall(self, ...)
        end)

        mt.__index = newcclosure(function(self, key)
            local result = oldIndex(self, key)
            if FZ.silent.on and typeof(self) == "Instance" and self:IsA("Mouse") and (key == "Hit" or key == "Target") then
                local target = findTarget(FZ.silent.fov)
                local part = target and targetPart(target.Character)
                if part then
                    if key == "Hit" then return CFrame.new(part.Position) end
                    return part
                end
            end
            return result
        end)

        setreadonly(mt, true)

        FZ.silent.conn = {
            Disconnect = function()
                pcall(function()
                    setreadonly(mt, false)
                    mt.__namecall = oldNamecall
                    mt.__index = oldIndex
                    setreadonly(mt, true)
                end)
            end,
        }
    end)

    if not ok then
        FZ.silent.on = false
        notify("Silent Aim: ошибка хука")
    end
end

--===================  HITBOX EXPANDER  ===================
local function applyHitbox()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local ch = plr.Character
            if ch then
                for _, part in ipairs(ch:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if not FZ.hitbox.sizes[part] then
                            FZ.hitbox.sizes[part] = part.Size
                        end
                        part.Size = Vector3.new(FZ.hitbox.size, FZ.hitbox.size, FZ.hitbox.size)
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
    for part, size in pairs(FZ.hitbox.sizes) do
        if typeof(part) == "Instance" and part.Parent then
            pcall(function()
                part.Size = size
                part.Transparency = 0
                part.CanCollide = true
                part.Massless = false
            end)
        end
    end
    FZ.hitbox.sizes = {}
end

local function setHitbox(on)
    FZ.hitbox.on = on and true or false
    if FZ.hitbox.conn then
        pcall(function() FZ.hitbox.conn:Disconnect() end)
        FZ.hitbox.conn = nil
    end
    if not FZ.hitbox.on then
        restoreHitbox()
        return
    end
    applyHitbox()
    FZ.hitbox.conn = RunService.Heartbeat:Connect(function()
        if FZ.hitbox.on then applyHitbox() end
    end)
end

--===================  ESP + СКЕЛЕТ  ===================
local function espGui()
    if FZ.esp.gui and FZ.esp.gui.Parent then return FZ.esp.gui end
    FZ.esp.gui = new("ScreenGui", {
        Name = "SpermaHubESP",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 50,
    }, PlayerGui)
    return FZ.esp.gui
end

local function createESP(plr)
    if plr == LP or FZ.esp.objects[plr] then return end
    local g = espGui()
    local data = { lines = {}, boxLines = {} }
    FZ.esp.objects[plr] = data

    local ch = plr.Character
    if ch then
        local hl = new("Highlight", {
            FillColor = Color3.fromRGB(255, 40, 40),
            OutlineColor = Color3.fromRGB(255, 255, 0),
            FillTransparency = 0.4,
            OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            Adornee = ch,
        }, g)
        data.highlight = hl
    end

    for i = 1, 4 do
        data.boxLines[i] = new("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 0),
            BorderSizePixel = 0,
            ZIndex = 6,
            Visible = false,
        }, g)
    end

    local bb = new("BillboardGui", {
        Name = "ESPName",
        Size = UDim2.new(0, 220, 0, 70),
        StudsOffset = Vector3.new(0, 3, 0),
        AlwaysOnTop = true,
    }, g)

    data.nameLabel = txt(bb, plr.Name, {
        Size = UDim2.new(1, 0, 0, 20),
        Font = F.bold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 255, 0),
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    data.hpLabel = txt(bb, "100 HP", {
        Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, 16),
        Font = F.bold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(80, 255, 120),
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    data.billboard = bb
end

local function removeESP(plr)
    local data = FZ.esp.objects[plr]
    if not data then return end
    if data.highlight then pcall(function() data.highlight:Destroy() end) end
    if data.billboard then pcall(function() data.billboard:Destroy() end) end
    for _, line in ipairs(data.boxLines) do
        if line then pcall(function() line:Destroy() end) end
    end
    FZ.esp.objects[plr] = nil
end

local function updateESP()
    local cam = workspace.CurrentCamera
    if not cam then return end
    for plr, data in pairs(FZ.esp.objects) do
        local ch = plr.Character
        if ch and alive(plr) then
            local head = ch:FindFirstChild("Head")
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local hrp = ch:FindFirstChild("HumanoidRootPart")

            if data.highlight then
                data.highlight.Adornee = ch
                data.highlight.Enabled = true
            end
            if data.billboard and head then data.billboard.Adornee = head end
            if data.nameLabel then data.nameLabel.Text = plr.Name end
            if data.hpLabel and hum then
                local hp = math.floor(hum.Health)
                local ratio = hum.Health / math.max(1, hum.MaxHealth)
                data.hpLabel.Text = hp .. " HP"
                data.hpLabel.TextColor3 = Color3.fromRGB(math.floor(255 * (1 - ratio)), math.floor(255 * ratio), 80)
            end

            if hrp and #data.boxLines >= 4 then
                local headPos = head and head.Position or (hrp.Position + Vector3.new(0, 1.5, 0))
                local footPos = hrp.Position - Vector3.new(0, 3, 0)
                local topV, topOn = cam:WorldToViewportPoint(headPos + Vector3.new(0, 0.5, 0))
                local botV, botOn = cam:WorldToViewportPoint(footPos)
                if topOn and botOn then
                    local height = math.abs(botV.Y - topV.Y)
                    local width = height * 0.55
                    local x, y = topV.X - width / 2, topV.Y
                    data.boxLines[1].Size = UDim2.new(0, width, 0, 1)
                    data.boxLines[1].Position = UDim2.new(0, x, 0, y)
                    data.boxLines[2].Size = UDim2.new(0, width, 0, 1)
                    data.boxLines[2].Position = UDim2.new(0, x, 0, y + height)
                    data.boxLines[3].Size = UDim2.new(0, 1, 0, height)
                    data.boxLines[3].Position = UDim2.new(0, x, 0, y)
                    data.boxLines[4].Size = UDim2.new(0, 1, 0, height)
                    data.boxLines[4].Position = UDim2.new(0, x + width, 0, y)
                    for _, line in ipairs(data.boxLines) do line.Visible = true end
                else
                    for _, line in ipairs(data.boxLines) do line.Visible = false end
                end
            end
        else
            if data.highlight then data.highlight.Adornee = nil end
            if data.billboard then data.billboard.Adornee = nil end
            for _, line in ipairs(data.boxLines) do line.Visible = false end
        end
    end
end

local function drawSkeleton()
    local cam = workspace.CurrentCamera
    if not cam then return end
    for plr in pairs(FZ.esp.objects) do
        local ch = plr.Character
        if ch and alive(plr) then
            local parts = {}
            for _, p in ipairs(ch:GetChildren()) do
                if p:IsA("BasePart") then parts[p.Name] = p end
            end
            local links
            if parts["UpperTorso"] then
                links = {
                    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
                    { "UpperTorso", "LeftUpperArm" }, { "UpperTorso", "RightUpperArm" },
                    { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
                    { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
                    { "LowerTorso", "LeftUpperLeg" }, { "LowerTorso", "RightUpperLeg" },
                    { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
                    { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
                }
            else
                links = {
                    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
                    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
                }
            end
            local frames = FZ.esp.skelFrames[plr]
            if not frames then frames = {} FZ.esp.skelFrames[plr] = frames end
            local g = espGui()
            for i, link in ipairs(links) do
                local p1, p2 = parts[link[1]], parts[link[2]]
                if p1 and p2 then
                    local v1, on1 = cam:WorldToViewportPoint(p1.Position)
                    local v2, on2 = cam:WorldToViewportPoint(p2.Position)
                    if on1 and on2 then
                        if not frames[i] then
                            frames[i] = new("Frame", {
                                BackgroundColor3 = Color3.fromRGB(255, 255, 0),
                                BorderSizePixel = 0,
                                ZIndex = 5,
                            }, g)
                        end
                        local f = frames[i]
                        local dx, dy = v2.X - v1.X, v2.Y - v1.Y
                        f.Size = UDim2.new(0, math.sqrt(dx * dx + dy * dy), 0, 2)
                        f.Position = UDim2.new(0, v1.X, 0, v1.Y)
                        f.Rotation = math.deg(math.atan2(dy, dx))
                        f.Visible = true
                    elseif frames[i] then
                        frames[i].Visible = false
                    end
                elseif frames[i] then
                    frames[i].Visible = false
                end
            end
            for i = #links + 1, #frames do frames[i].Visible = false end
        end
    end
end

local function setESP(on)
    FZ.esp.on = on and true or false
    if FZ.esp.conn then
        pcall(function() FZ.esp.conn:Disconnect() end)
        FZ.esp.conn = nil
    end
    if not FZ.esp.on then
        for plr in pairs(FZ.esp.objects) do removeESP(plr) end
        FZ.esp.objects = {}
        for _, frames in pairs(FZ.esp.skelFrames) do
            for _, f in ipairs(frames) do pcall(function() f:Destroy() end) end
        end
        FZ.esp.skelFrames = {}
        return
    end

    espGui()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then createESP(plr) end
    end
    FZ.esp.conn = RunService.RenderStepped:Connect(function()
        if not FZ.esp.on then return end
        updateESP()
        if FZ.esp.skel then drawSkeleton() end
    end)
end

--===================  FLY  ===================
local function setFly(on)
    FZ.fly.on = on and true or false
    if FZ.fly.conn then
        pcall(function() FZ.fly.conn:Disconnect() end)
        FZ.fly.conn = nil
    end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not FZ.fly.on then
        if FZ.fly.bv then pcall(function() FZ.fly.bv:Destroy() end) FZ.fly.bv = nil end
        if FZ.fly.bg then pcall(function() FZ.fly.bg:Destroy() end) FZ.fly.bg = nil end
        if hum then hum.PlatformStand = false end
        return
    end
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root or not hum then
        FZ.fly.on = false
        return
    end

    FZ.fly.bv = new("BodyVelocity", { MaxForce = Vector3.new(1e5, 1e5, 1e5), Velocity = Vector3.new(0, 0, 0) }, root)
    FZ.fly.bg = new("BodyGyro", { MaxTorque = Vector3.new(1e5, 1e5, 1e5), P = 10000, D = 200 }, root)
    hum.PlatformStand = true

    FZ.fly.conn = RunService.RenderStepped:Connect(function()
        if not FZ.fly.on then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local d = Vector3.new(0, 0, 0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0, 1, 0) end
        if FZ.fly.bv then
            FZ.fly.bv.Velocity = d.Magnitude > 0 and d.Unit * FZ.fly.speed or Vector3.new(0, 0, 0)
        end
        if FZ.fly.bg then FZ.fly.bg.CFrame = cam.CFrame end
    end)
end

--===================  NOCLIP  ===================
local function setNoclip(on)
    FZ.noclip.on = on and true or false
    if FZ.noclip.conn then
        pcall(function() FZ.noclip.conn:Disconnect() end)
        FZ.noclip.conn = nil
    end
    if not FZ.noclip.on then
        local ch = LP.Character
        if ch then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
            end
        end
        return
    end
    FZ.noclip.conn = RunService.Stepped:Connect(function()
        if not FZ.noclip.on then return end
        local ch = LP.Character
        if not ch then return end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end

--===================  CLICK TP  ===================
local function setClickTp(on)
    FZ.clickTp.on = on and true or false
    if FZ.clickTp.conn then
        pcall(function() FZ.clickTp.conn:Disconnect() end)
        FZ.clickTp.conn = nil
    end
    if not FZ.clickTp.on then return end
    FZ.clickTp.conn = UIS.InputBegan:Connect(function(input, gpe)
        if gpe or not FZ.clickTp.on then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local ch = LP.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local mouse
        pcall(function() mouse = LP:GetMouse() end)
        if not mouse or not mouse.Target then return end
        root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, FZ.clickTp.height, 0))
        root.Velocity = Vector3.new(0, 0, 0)
    end)
end

--===================  WALK SPEED  ===================
local function applyWalkSpeed()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = FZ.walk.on and FZ.walk.speed or 16
    end
end

local function setWalkSpeed(on)
    FZ.walk.on = on and true or false
    if FZ.walk.conn then
        pcall(function() FZ.walk.conn:Disconnect() end)
        FZ.walk.conn = nil
    end
    applyWalkSpeed()
    if not FZ.walk.on then return end
    FZ.walk.conn = RunService.Heartbeat:Connect(function()
        if not FZ.walk.on then return end
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum and math.abs(hum.WalkSpeed - FZ.walk.speed) > 0.1 then
            hum.WalkSpeed = FZ.walk.speed
        end
    end)
end

--===================  KILL PLAYER  ===================
local function killPlayer(targetPlayer)
    if not targetPlayer then return end
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    local hum = myChar:FindFirstChildOfClass("Humanoid")
    local backpack = LP:FindFirstChild("Backpack")
    if not hum or not backpack then return end

    myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 0.5, 0)
    myRoot.Velocity = Vector3.new(0, 0, 0)

    local tool = nil
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then tool = item break end
    end
    if not tool then
        for _, item in ipairs(myChar:GetChildren()) do
            if item:IsA("Tool") then tool = item break end
        end
    end
    if not tool then
        notify("Kill Player: нет оружия")
        return
    end

    if tool.Parent == backpack then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.1)
    end

    task.spawn(function()
        for _ = 1, 30 do
            if not tool or not tool.Parent then break end
            if targetRoot and targetRoot.Parent then
                myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 0.5, 0)
                myRoot.Velocity = Vector3.new(0, 0, 0)
            end
            pcall(function() tool:Activate() end)
            task.wait(0.03)
        end
    end)
end

-- всё выключить (вызывается из Unload)
local function teardownFeatures()
    pcall(function() setAimbot(false) end)
    pcall(function() setSilentAim(false) end)
    pcall(function() setHitbox(false) end)
    pcall(function() setESP(false) end)
    pcall(function() setFly(false) end)
    pcall(function() setNoclip(false) end)
    pcall(function() setClickTp(false) end)
    pcall(function() setWalkSpeed(false) end)
    if FZ.esp.gui then pcall(function() FZ.esp.gui:Destroy() end) FZ.esp.gui = nil end
end

--=================================================================
--  КОНТЕНТ СТРАНИЦ (демо по референсу)
--=================================================================
local function buildWorld(p)
    local main = p:card("Main")
    main:toggle("Night Mode", true, true)
    main:dropdown("SkyBox", {"Night 1", "Night 2", "Night 3", "None"}, "Night 2", true)
    main:toggle("Post Processing", false, true)
    main:slider("Asus Walls", 0, 100, 0, 1)
    main:slider("Asus Props", 0, 100, 40, 1)
    main:dropdown("Removals", {"Smoke, HE, Flashb", "Smoke, HE", "Smoke", "None"}, "Smoke, HE, Flashb")
    main:dropdown("Ragdoll Physics", {"Disabled", "Enabled"}, "Disabled")

    local fog = p:card("Fog")
    fog:toggle("Enable Fog", false, true)
    fog:slider("Start Distance", 0, 100, 0, 1)
    fog:slider("End Distance", 0, 100, 100, 1)
    fog:slider("Density", 0, 100, 50, 1)

    local misc = p:card("Misc", "right")
    misc:toggle("NoScope Crosshair", true)
    misc:dropdown("Autowall Crosshair", {"Dot", "Cross", "Circle", "None"}, "Dot")
    misc:toggle("Damage Indicator", true, true)
    misc:toggle("Preserve Kill Feed", true)
    misc:dropdown("Reveals", {"Ranks", "All", "None"}, "Ranks")

    local hit = p:card("Hit", "right")
    hit:toggle("Hit Marker", true, true)
    hit:toggle("Hit Sound", true)
    hit:slider("Volume", 0, 100, 50, 1)
    hit:toggle("Client Bullet Impacts", true, true)
    hit:toggle("Server Bullet Impacts", true, true)
    hit:slider("Duration", 0, 4, 4.0, 0.1)
end

local function buildPlaceholder(p, name)
    local main = p:card("Main")
    main:toggle(name .. " Enabled", false, true)
    main:dropdown("Mode", {"Default", "Custom", "Legacy"}, "Default", false)
    main:slider("Smoothing", 0, 100, 50, 1)
    main:text("Страница-заглушка: сюда вешаются твои элементы через p:card(), card:toggle(), card:slider(), card:dropdown().")
end

--=================================================================
--  СТРАНИЦЫ НА РЕАЛЬНЫХ ФУНКЦИЯХ
--=================================================================
local function buildRagebot(p)
    local aim = p:card("Aimbot")
    aim:toggle("Enabled", false, true, function(on) setAimbot(on) end)
    aim:slider("FOV", 20, 600, 120, 1, function(v) FZ.aim.fov = v end)
    aim:slider("Smooth", 0.05, 1, 0.3, 0.05, function(v) FZ.aim.smooth = v end)

    local silent = p:card("Silent Aim", "right")
    silent:toggle("Enabled", false, true, function(on) setSilentAim(on) end)
    silent:slider("FOV", 20, 600, 150, 1, function(v) FZ.silent.fov = v end)
    silent:text("Нужны hookfunction, getrawmetatable, setreadonly, newcclosure — без них включение отменится.")

    local hit = p:card("Hitbox")
    hit:toggle("Enabled", false, true, function(on) setHitbox(on) end)
    hit:slider("Size", 1, 20, 5, 1, function(v) FZ.hitbox.size = v end)
end

local function buildPlayers(p)
    local esp = p:card("ESP")
    esp:toggle("Enabled", false, true, function(on) setESP(on) end)
    esp:toggle("Skeleton", true, false, function(on) FZ.esp.skel = on end)
    esp:text("Highlight, бокс, ник и HP над головой.")
end

local function buildWeapon(p)
    local kill = p:card("Kill Player")
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then table.insert(names, plr.Name) end
    end
    if #names == 0 then names = { "(никого)" } end
    kill:dropdown("Target", names, names[1], false)

    local killToggle
    killToggle = kill:toggle("Kill", false, false, function(on)
        if not on then return end
        killToggle:set(false, true)
        local name = CFG["Weapon/Kill Player/Target"]
        local plr = name and Players:FindFirstChild(name)
        killPlayer(plr)
    end)
    kill:text("Телепорт в цель и 30 ударов текущим инструментом.")
end

local function buildMain(p)
    local move = p:card("Movement")
    move:toggle("Fly", false, true, function(on) setFly(on) end)
    move:slider("Fly Speed", 10, 300, 50, 1, function(v) FZ.fly.speed = v end)
    move:toggle("Noclip", false, true, function(on) setNoclip(on) end)
    move:toggle("Click TP", false, true, function(on) setClickTp(on) end)
    move:slider("TP Height", 0, 20, 3, 1, function(v) FZ.clickTp.height = v end)

    local ws = p:card("Walk Speed", "right")
    ws:toggle("Enabled", false, true, function(on) setWalkSpeed(on) end)
    ws:slider("Speed", 16, 300, 16, 1, function(v)
        FZ.walk.speed = v
        applyWalkSpeed()
    end)
end

--=================================================================
--  СПИСОК СТРАНИЦ
--=================================================================
-- icon = ключ из ICONS (таблица иконок выше), а не сам глиф
local PAGES = {
    {group = "Aimbot",        name = "Ragebot",   icon = "ragebot"},
    {group = "Aimbot",        name = "Anti Aim",  icon = "antiaim"},
    {group = "Aimbot",        name = "Legitbot",  icon = "legitbot"},
    {group = "Visuals",       name = "Players",   icon = "players"},
    {group = "Visuals",       name = "Weapon",    icon = "weapon"},
    {group = "Visuals",       name = "Grenades",  icon = "grenades"},
    {group = "Visuals",       name = "Bomb",      icon = "bomb"},
    {group = "Visuals",       name = "World",     icon = "world"},
    {group = "Visuals",       name = "View",      icon = "view"},
    {group = "Miscellaneous", name = "Main",      icon = "main"},
    {group = "Miscellaneous", name = "Inventory", icon = "inventory"},
    {group = "Miscellaneous", name = "Scripts",   icon = "scripts"},
    {group = "Miscellaneous", name = "Configs",   icon = "configs"},
}

local BUILDERS = {
    World = buildWorld,
    Ragebot = buildRagebot,
    Players = buildPlayers,
    Weapon = buildWeapon,
    Main = buildMain,
}

local pageByName = {}
local currentPage

local function applySearch(query)
    local q = string.lower(query or "")
    for _, g in ipairs(navGroups) do
        local any = false
        for _, def in ipairs(g.items) do
            local match = (q == "") or (string.find(string.lower(def.name), q, 1, true) ~= nil)
            def.btn.Visible = match
            if match then any = true end
        end
        g.label.Visible = any
        g.spacer.Visible = any
    end
end

local function showPage(def)
    closePopup()
    if not def.page then
        def.page = createPage(def)
        local builder = BUILDERS[def.name] or function(p) buildPlaceholder(p, def.name) end
        local ok, err = pcall(builder, def.page)
        if not ok then
            warn("[SpermaHubUI] build '" .. def.name .. "': " .. tostring(err))
        end
    end
    for _, other in ipairs(PAGES) do
        if other.page then
            other.page.holder.Visible = (other == def)
        end
    end
    currentPage = def
end

local function setSelected(def)
    for _, other in ipairs(PAGES) do
        if other ~= def then
            other.selected = false
            other.btn.BackgroundTransparency = 1
            other.navStroke.Transparency = 1
            other.nameLbl.TextColor3 = C.dim
            iconTint(other.iconSlot, C.accent)
        end
    end
    def.selected = true
    def.btn.BackgroundTransparency = 0.15
    def.navStroke.Transparency = 0.25
    def.nameLbl.TextColor3 = C.text
    iconTint(def.iconSlot, Color3.fromRGB(168, 212, 240))
    showPage(def)
end

-- построение сайдбара
local groupsByTitle = {}
for _, def in ipairs(PAGES) do
    local g = groupsByTitle[def.group]
    if not g then
        g = addGroup(def.group)
        groupsByTitle[def.group] = g
    end
    buildNavItem(g, def)
    pageByName[def.name] = def
    def.btn.MouseButton1Click:Connect(function()
        applySearch("")
        searchBox.Text = ""
        searchBox.Visible = false
        setSelected(def)
    end)
end

--=================================================================
--  ДЕЙСТВИЯ ШАПКИ
--=================================================================
local function saveConfig()
    local ok, json = pcall(function() return Http:JSONEncode(CFG) end)
    if ok and type(writefile) == "function" then
        pcall(writefile, "spermahub_config.json", json)
        notify("Config saved")
    elseif ok then
        notify("Saved (no writefile)")
    else
        notify("Save failed")
    end
end

saveBtn.MouseButton1Click:Connect(saveConfig)

saveBtn.MouseEnter:Connect(function()
    Tween:Create(saveBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(17, 23, 33)}):Play()
end)
saveBtn.MouseLeave:Connect(function()
    Tween:Create(saveBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(12, 17, 25)}):Play()
end)

searchBtn.MouseButton1Click:Connect(function()
    searchBox.Visible = not searchBox.Visible
    if searchBox.Visible then
        searchBox:CaptureFocus()
    else
        searchBox.Text = ""
        applySearch("")
    end
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    applySearch(searchBox.Text)
end)

searchBox.FocusLost:Connect(function()
    if searchBox.Text == "" then
        searchBox.Visible = false
        applySearch("")
    end
end)

gearBtn.MouseButton1Click:Connect(function()
    openPopup(gearBtn, {"Save config", "Unload"}, function(pick)
        if pick == "Save config" then
            saveConfig()
        elseif pick == "Unload" then
            if getgenv and getgenv().SpermaHubUI then
                getgenv().SpermaHubUI.Unload()
            end
        end
    end, 170)
end)

--=================================================================
--  ПОКАЗ / СКРЫТИЕ
--=================================================================
local opened = true

local function setOpen(state)
    opened = state
    gui.Enabled = state
    Tween:Create(blur, TweenInfo.new(0.2), {Size = state and 14 or 0}):Play()
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setOpen(not opened)
    elseif input.KeyCode == Enum.KeyCode.Escape and opened then
        setOpen(false)
    end
end)

backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        closePopup()
    end
end)

--=================================================================
--  API
--=================================================================
local function unload()
    pcall(teardownFeatures)
    pcall(function() gui:Destroy() end)
    pcall(function() blur:Destroy() end)
    if getgenv then
        if getgenv().SpermaHubUI and getgenv().SpermaHubUI.Gui == gui then
            getgenv().SpermaHubUI = nil
        end
        if getgenv().NeverloseUI and getgenv().NeverloseUI.Gui == gui then
            getgenv().NeverloseUI = nil
        end
    end
end

local api = {
    Gui = gui,
    Panel = panel,
    Config = CFG,
    Notify = notify,
    Save = saveConfig,
    Unload = unload,
    Toggle = setOpen,
    Pages = pageByName,
    Icons = ICONS,
    SetIcon = setIcon,
    RefreshIcons = refreshIcons,
    Features = FZ,
    SetAimbot = setAimbot,
    SetSilentAim = setSilentAim,
    SetHitbox = setHitbox,
    SetESP = setESP,
    SetFly = setFly,
    SetNoclip = setNoclip,
    SetClickTp = setClickTp,
    SetWalkSpeed = setWalkSpeed,
    KillPlayer = killPlayer,
}

getgenv().SpermaHubUI = api
getgenv().NeverloseUI = api  -- старое имя, оставлено для совместимости

-- стартовая страница
setSelected(pageByName.World or PAGES[1])
notify("SPERMAHUB loaded \u{2022} RShift")
