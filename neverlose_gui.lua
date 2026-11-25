--=================================================================
--  NEVERLOSE-STYLE INTERFACE  (Roblox, standalone)
--=================================================================
--  Никаких внешних библиотек. Всё на голых Instance.
--
--  API:
--    getgenv().NeverloseUI.Config          -- все значения
--    getgenv().NeverloseUI.Notify(text)    -- тост
--    getgenv().NeverloseUI.Save()          -- сохранить в neverlose_config.json
--    getgenv().NeverloseUI.Unload()        -- выгрузить
--    getgenv().NeverloseUI.Icons           -- таблица иконок (glyph / image)
--    getgenv().NeverloseUI.SetIcon(name, { image = "rbxassetid://..." })
--    getgenv().NeverloseUI.RefreshIcons()  -- перерисовать все иконки
--
--  Показать/скрыть: RightShift (или Escape - закрыть)
--=================================================================

local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local Tween     = game:GetService("TweenService")
local Lighting  = game:GetService("Lighting")
local Http      = game:GetService("HttpService")
local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

--=================================================================
--  КОНСТАНТЫ / ПАЛИТРА
--=================================================================
local W, H      = 1200, 872
local SB        = 290          -- ширина сайдбара
local HEADER    = 104          -- высота шапки

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
--    getgenv().NeverloseUI.SetIcon("weapon", { image = "rbxassetid://1234567890" })
--    getgenv().NeverloseUI.Icons.weapon.image = 1234567890
--    getgenv().NeverloseUI.RefreshIcons()
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
if getgenv and getgenv().NeverloseUI and getgenv().NeverloseUI.Unload then
    pcall(function() getgenv().NeverloseUI.Unload() end)
end

local gui = new("ScreenGui", {
    Name = "NeverloseUI",
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
local logo = txt(sidebar, "NEVERLOSE", {
    Position = UDim2.new(0, 26, 0, 24),
    Size = UDim2.new(1, -52, 0, 46),
    Font = F.black,
    TextSize = 34,
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
                if not ok then warn("[NeverloseUI] toggle callback: " .. tostring(err)) end
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
                if not ok then warn("[NeverloseUI] slider callback: " .. tostring(err)) end
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
                if not ok then warn("[NeverloseUI] dropdown callback: " .. tostring(err)) end
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
            warn("[NeverloseUI] build '" .. def.name .. "': " .. tostring(err))
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
        pcall(writefile, "neverlose_config.json", json)
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
            if getgenv and getgenv().NeverloseUI then
                getgenv().NeverloseUI.Unload()
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
    pcall(function() gui:Destroy() end)
    pcall(function() blur:Destroy() end)
    if getgenv and getgenv().NeverloseUI then
        getgenv().NeverloseUI = nil
    end
end

getgenv().NeverloseUI = {
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
}

-- стартовая страница
setSelected(pageByName.World or PAGES[1])
notify("Neverlose UI loaded \u{2022} RShift")
