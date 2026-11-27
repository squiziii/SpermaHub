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
--    getgenv().SpermaHubHUD                -- HUD (порт Interface.java)
--    getgenv().SpermaHubHUD.SetEnabled("arraylist", false)
--    getgenv().SpermaHubHUD.Push("text")   -- нотификация в HUD
--    getgenv().SpermaHubHUD.SetTargetESP(true)  -- маркер над целью (targetesp)
--    getgenv().SpermaHubHUD.SetArrows(true)     -- стрелки на игроков (arrows)
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
local W, H      = 760, 520
local SB        = 132          -- ширина рейки категорий
local HEADER    = 40           -- высота шапки

local C = {
    panel     = Color3.fromRGB(11, 11, 15),
    sidebar   = Color3.fromRGB(16, 16, 21),
    card      = Color3.fromRGB(17, 17, 23),
    input     = Color3.fromRGB(23, 23, 31),
    track     = Color3.fromRGB(40, 40, 52),
    line      = Color3.fromRGB(35, 35, 46),
    cardLine  = Color3.fromRGB(52, 46, 92),
    accent    = Color3.fromRGB(150, 140, 255),
    accentDim = Color3.fromRGB(58, 52, 108),
    text      = Color3.fromRGB(240, 240, 248),
    label     = Color3.fromRGB(206, 206, 222),
    dim       = Color3.fromRGB(138, 138, 156),
    faint     = Color3.fromRGB(92, 92, 110),
    knob      = Color3.fromRGB(236, 236, 250),
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

-------------------------------------------------------------------
--  АТЛАС ИКОНОК (запечённый MSDF -> tools/bake_msdf_atlas.py)
-------------------------------------------------------------------
--  Сам MSDF-атлас Roblox показать не может: в RGB лежит карта расстояний до
--  края, а не цвет, поэтому на экране была бы радужная каша. tools/bake_msdf_atlas.py
--  декодирует поле, печёт обычный лист icons_atlas.png с альфой и печатает
--  прямоугольники (icons_atlas_rects.lua). Лист грузится в Roblox как картинка,
--  id вставляется сюда:
--     local ICON_ATLAS = "rbxassetid://1234567890"
--     local ATLAS_RECTS = { weapon = { x = 6, y = 6, w = 88, h = 84, sheet = 1024 }, ... }
--
--  На лету:
--     getgenv().SpermaHubUI.SetAtlas("rbxassetid://1234567890", rects)
--     getgenv().SpermaHubUI.SetAtlas(nil)   -- назад к глифам
--  Пока атлас не подключён, рисуются прежние глифы/примитивы.
--=================================================================
local ICON_ATLAS = ""    -- "rbxassetid://..." или "" (глифы)
local ATLAS_RECTS = {}   -- [имя иконки] = { x, y, w, h, sheet }

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

-- прямоугольник иконки в атласе (nil, если атлас не подключён)
local function atlasRect(name)
    if ICON_ATLAS == "" then return nil end
    return ATLAS_RECTS[name]
end

-- вернуть ImageLabel к целой картинке (без среза атласа)
local function resetAtlas(slot)
    slot.image.Image = ""
    slot.image.ImageRectOffset = Vector2.new(0, 0)
    slot.image.ImageRectSize = Vector2.new(0, 0)
    slot.image.ScaleType = Enum.ScaleType.Fit
    slot.image.Size = UDim2.fromOffset(slot.side, slot.side)
end

-- натянуть иконку из атласа: срез + масштаб по пропорциям глифа
local function applyAtlas(slot, rect)
    local w = math.max(rect.w or 1, 1)
    local h = math.max(rect.h or 1, 1)
    slot.image.ImageRectOffset = Vector2.new(rect.x or 0, rect.y or 0)
    slot.image.ImageRectSize = Vector2.new(w, h)
    slot.image.ScaleType = Enum.ScaleType.Stretch
    local k = math.min(slot.side / w, slot.side / h)
    slot.image.Size = UDim2.fromOffset(
        math.max(2, math.floor(w * k + 0.5)),
        math.max(2, math.floor(h * k + 0.5)))
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
    local rect = (not src) and atlasRect(slot.name) or nil
    if rect then src = ICON_ATLAS end
    if not rect then resetAtlas(slot) end

    if src then
        slot.image.Image = src
        if rect then applyAtlas(slot, rect) end
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

    local slot = { name = name, holder = holder, label = label, image = image, side = side, builtin = cfg.builtin }
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

-- подключить/сменить атлас: asset id + (необязательно) таблица прямоугольников.
-- setAtlas(nil) возвращает прежние глифы.
local function setAtlas(asset, rects)
    local src = iconSrc({ image = asset })
    ICON_ATLAS = src or ""
    if type(rects) == "table" then
        for k in pairs(ATLAS_RECTS) do ATLAS_RECTS[k] = nil end
        for k, v in pairs(rects) do ATLAS_RECTS[k] = v end
    end
    refreshIcons()
    return ICON_ATLAS
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

local panel = new("Frame", {
    Name = "ClickGUI",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H),
    BackgroundColor3 = C.panel,
    BackgroundTransparency = 0.07,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    Active = true,
}, gui)
corner(panel, 9)
stroke(panel, C.line, 0.4)

local scale = new("UIScale", {Scale = 1}, panel)

local function fitScale()
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
    local s = math.min(vp.X / (W + 60), vp.Y / (H + 60))
    scale.Scale = math.clamp(s, 0.55, 1.2)
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
local camWatch = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    fitScale()
    hookCamera()
end)

local blur = Instance.new("BlurEffect")
blur.Size = 18
blur.Enabled = true
blur.Parent = Lighting

local function bindPanelDrag(handle)
    local dragging = false
    local startMouse, startPos
    handle.InputBegan:Connect(function(input)
        if not input then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        startMouse = UIS:GetMouseLocation()
        startPos = panel.Position
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging or not input then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local m = UIS:GetMouseLocation()
        local d = m - startMouse
        panel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end)
    UIS.InputEnded:Connect(function(input)
        if input and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
        end
    end)
end

--=================================================================
--  РЕЙКА КАТЕГОРИЙ
--=================================================================
local rail = new("Frame", {
    Name = "Rail",
    Size = UDim2.new(0, SB, 1, 0),
    BackgroundColor3 = C.sidebar,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
}, panel)
corner(rail, 9)
bindPanelDrag(rail)

corner(new("Frame", {
    Position = UDim2.fromOffset(14, 18),
    Size = UDim2.fromOffset(3, 13),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
}, rail), 1)

txt(rail, "SPERMAHUB", {
    Position = UDim2.fromOffset(23, 13),
    Size = UDim2.new(1, -30, 0, 22),
    Font = F.black,
    TextSize = 14,
    TextColor3 = C.text,
})

new("Frame", {
    Position = UDim2.new(0, 10, 0, 42),
    Size = UDim2.new(1, -20, 0, 1),
    BackgroundColor3 = C.line,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
}, rail)

local nav = new("ScrollingFrame", {
    Position = UDim2.new(0, 6, 0, 50),
    Size = UDim2.new(1, -12, 1, -60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollingEnabled = true,
}, rail)
new("UIListLayout", {
    Padding = UDim.new(0, 1),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, nav)
new("UIPadding", {PaddingBottom = UDim.new(0, 10)}, nav)

local navOrd = counter()
local navGroups = {}

local function addGroup(title)
    local spacer = new("Frame", {
        Size = UDim2.new(1, 0, 0, 9),
        BackgroundTransparency = 1,
        LayoutOrder = navOrd(),
    }, nav)
    local lbl = txt(nav, title, {
        Size = UDim2.new(1, 0, 0, 15),
        Font = F.bold,
        TextSize = 10,
        TextColor3 = C.faint,
        LayoutOrder = navOrd(),
    })
    new("UIPadding", {PaddingLeft = UDim.new(0, 8)}, lbl)

    local g = {label = lbl, spacer = spacer, items = {}}
    table.insert(navGroups, g)
    return g
end

local function buildNavItem(group, def)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = C.accentDim,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        LayoutOrder = navOrd(),
    }, nav)
    corner(btn, 4)
    local st = stroke(btn, C.accent, 1, 1)

    local sel = new("Frame", {
        Position = UDim2.fromOffset(0, 7),
        Size = UDim2.fromOffset(2, 14),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        Visible = false,
    }, btn)
    corner(sel, 1)

    local icon = iconSlot(btn, def.icon, {
        position = UDim2.new(0, 9, 0, 0),
        size = UDim2.new(0, 14, 1, 0),
        textSize = 12,
        font = F.bold,
        color = C.dim,
    })
    local name = txt(btn, def.name, {
        Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -36, 1, 0),
        TextSize = 12,
        Font = F.med,
        TextColor3 = C.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    btn.MouseEnter:Connect(function()
        if def.selected then return end
        Tween:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.82}):Play()
        name.TextColor3 = C.label
    end)
    btn.MouseLeave:Connect(function()
        if def.selected then return end
        Tween:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
        name.TextColor3 = C.dim
    end)

    def.btn = btn
    def.iconSlot = icon
    def.nameLbl = name
    def.navStroke = st
    def.selBar = sel
    table.insert(group.items, def)
    return def
end

--=================================================================
--  ШАПКА
--=================================================================
local header = new("Frame", {
    Name = "Header",
    Position = UDim2.new(0, SB, 0, 0),
    Size = UDim2.new(1, -SB, 0, HEADER),
    BackgroundTransparency = 1,
}, panel)
bindPanelDrag(header)

new("Frame", {
    Position = UDim2.new(0, 12, 1, -1),
    Size = UDim2.new(1, -24, 0, 1),
    BackgroundColor3 = C.line,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
}, header)

local pageTitle = txt(header, "", {
    Position = UDim2.fromOffset(16, 0),
    Size = UDim2.new(0, 240, 1, 0),
    Font = F.bold,
    TextSize = 13,
    TextColor3 = C.text,
})

local function headBtn(iconName, rightX, builtin)
    local b = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, rightX, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, header)
    local slot = iconSlot(b, iconName, {
        textSize = 13,
        font = F.bold,
        color = C.dim,
        builtin = builtin,
    })
    b.MouseEnter:Connect(function() iconTint(slot, C.text) end)
    b.MouseLeave:Connect(function() iconTint(slot, C.dim) end)
    return b, slot
end

local searchBtn = headBtn("search", -118, magnifier)
local saveBtn = headBtn("save", -88)
local gearBtn = headBtn("gear", -58)

local closeBtn = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(24, 24),
    BackgroundColor3 = C.input,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    Text = "×",
    Font = F.bold,
    TextSize = 16,
    TextColor3 = C.dim,
    AutoButtonColor = false,
}, header)
corner(closeBtn, 4)
closeBtn.MouseEnter:Connect(function()
    closeBtn.TextColor3 = Color3.fromRGB(238, 122, 122)
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.TextColor3 = C.dim
end)

local searchBox = new("TextBox", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -298, 0.5, 0),
    Size = UDim2.fromOffset(170, 24),
    BackgroundColor3 = C.input,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Search",
    PlaceholderColor3 = C.faint,
    Font = F.med,
    TextSize = 12,
    TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Visible = false,
}, header)
corner(searchBox, 4)
stroke(searchBox, C.line, 0.25)
new("UIPadding", {PaddingLeft = UDim.new(0, 8)}, searchBox)

--=================================================================
--  КОНТЕНТ (страницы)
--=================================================================
local body = new("Frame", {
    Name = "Body",
    Position = UDim2.new(0, SB + 14, 0, HEADER + 10),
    Size = UDim2.new(1, -(SB + 14) - 14, 1, -(HEADER + 10) - 14),
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

    if getgenv and getgenv().SpermaHubHUD and getgenv().SpermaHubHUD.Push then
        pcall(getgenv().SpermaHubHUD.Push, text)
    end

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
-- вызовы бывают и control:Set(v), и control.Set(v) — нормализуем аргументы
local function normSetter(fn)
    return function(a, b, c)
        if type(a) == "table" and a.frame then
            return fn(b, c)
        end
        return fn(a, b)
    end
end

-- реестр всех контролов по ключу конфига: нужен, чтобы накатить сохранённые значения
local CONTROLS = {}

local function buildToggle(parent, label, default, hasEye, key, onChange)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
    }, parent)

    local lbl = txt(row, label, {
        Size = UDim2.new(1, hasEye and -52 or -28, 1, 0),
        TextSize = 12,
        TextColor3 = C.label,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local eyeBtn, eyeIcon
    if hasEye then
        eyeBtn = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -24, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 5,
        }, row)
        eyeIcon = iconSlot(eyeBtn, "eye", {
            textSize = 12,
            font = F.reg,
            color = C.faint,
            zIndex = 5,
            imageSize = 14,
        })
    end

    local box = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = C.input,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
    }, row)
    corner(box, 3)
    local boxStroke = stroke(box, C.line, 0.1)

    local fill = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        Visible = false,
    }, box)
    corner(fill, 2)

    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    }, row)

    local state = default and true or false

    local function paint()
        fill.Visible = state
        boxStroke.Color = state and C.accent or C.line
        boxStroke.Transparency = state and 0.15 or 0.1
        lbl.TextColor3 = state and C.text or C.label
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
            lbl.TextTransparency = shown and 0 or 0.6
            iconTint(eyeIcon, shown and C.faint or C.dim)
        end)
    end

    local ctrl = {
        frame = row,
        set = normSetter(set),
        get = function() return state end,
    }
    if key then CONTROLS[key] = ctrl end
    return ctrl
end

local function buildInput(parent, label, default, onChange)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
    }, parent)

    txt(row, label, {
        Size = UDim2.new(1, -134, 1, 0),
        TextSize = 11,
        TextColor3 = C.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(124, 20),
        BackgroundColor3 = C.input,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = tostring(default or ""),
        Font = F.reg,
        TextSize = 11,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, row)
    corner(box, 3)
    stroke(box, C.line, 0.2)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
    }, box)

    local value = tostring(default or "")

    local function set(v, silent)
        value = tostring(v or "")
        box.Text = value
        if not silent and onChange then
            task.spawn(function()
                local ok, err = pcall(onChange, value)
                if not ok then warn("[SpermaHubUI] input callback: " .. tostring(err)) end
            end)
        end
    end

    box.FocusLost:Connect(function() set(box.Text) end)
    set(value, true)

    return {
        frame = row,
        set = normSetter(set),
        get = function() return value end,
    }
end

local function buildSlider(parent, label, minV, maxV, default, step, key, onChange)
    step = step or 1
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    }, parent)

    txt(row, label, {
        Size = UDim2.new(1, -46, 0, 14),
        TextSize = 11,
        TextColor3 = C.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local valLbl = txt(row, "", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(46, 14),
        TextSize = 11,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = new("Frame", {
        Position = UDim2.new(0, 0, 0, 19),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = C.track,
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
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(9, 9),
        BackgroundColor3 = C.text,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, track)
    corner(thumb, 5)

    local hit = new("TextButton", {
        Position = UDim2.new(0, 0, 0, 10),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
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

    local ctrl = {
        frame = row,
        set = normSetter(set),
        get = function() return value end,
    }
    if key then CONTROLS[key] = ctrl end
    return ctrl
end

local function buildDropdown(parent, label, options, default, hasEye, key, onChange)
    options = options or {}
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
    }, parent)

    txt(row, label, {
        Size = UDim2.new(1, hasEye and -160 or -134, 1, 0),
        TextSize = 11,
        TextColor3 = C.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    if hasEye then
        local eyeBtn = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -128, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 5,
        }, row)
        iconSlot(eyeBtn, "eye", {
            textSize = 12,
            font = F.reg,
            color = C.faint,
            zIndex = 5,
            imageSize = 14,
        })
    end

    local box = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(124, 20),
        BackgroundColor3 = C.input,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(box, 3)
    stroke(box, C.line, 0.2)

    local value = tostring(default or options[1] or "")
    local valLbl = txt(box, value, {
        Position = UDim2.new(0, 7, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        TextSize = 11,
        TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    iconSlot(box, "arrow", {
        anchor = Vector2.new(1, 0.5),
        position = UDim2.new(1, -6, 0.5, 0),
        size = UDim2.fromOffset(10, 10),
        textSize = 11,
        font = F.bold,
        color = C.faint,
        imageSize = 9,
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
        end, 124)
    end)

    if key then CFG[key] = value end

    local ctrl = {
        frame = row,
        set = normSetter(set),
        get = function() return value end,
    }
    if key then CONTROLS[key] = ctrl end
    return ctrl
end

local function buildLabel(parent, text)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, parent)
    local lbl = txt(row, text, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextSize = 10,
        TextColor3 = C.faint,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    return {
        frame = row,
        set = normSetter(function(v) lbl.Text = tostring(v) end),
        get = function() return lbl.Text end,
    }
end

--=================================================================
--  КАРТОЧКА
--=================================================================
local function addCard(column, title, pageName)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
    }, column)
    corner(frame, 6)
    stroke(frame, C.line, 0.45)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 11),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }, frame)
    new("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)

    local ord = counter()

    local head = new("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder = ord(),
    }, frame)
    new("Frame", {
        Position = UDim2.fromOffset(0, 5),
        Size = UDim2.fromOffset(2, 9),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, head)
    txt(head, title, {
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -8, 1, 0),
        Font = F.bold,
        TextSize = 11,
        TextColor3 = C.label,
    })

    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.line,
        BackgroundTransparency = 0.4,
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

    function card:input(label, default, cb)
        local c = buildInput(frame, label, default, cb)
        c.frame.LayoutOrder = ord()
        return c
    end

    function card:button(label, cb)
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = C.input,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = ord(),
        }, frame)
        corner(btn, 4)
        stroke(btn, C.line, 0.3)
        txt(btn, label, {
            Size = UDim2.fromScale(1, 1),
            TextSize = 11,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.05 end)
        btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 0.2 end)
        btn.MouseButton1Click:Connect(function()
            if cb then task.spawn(cb) end
        end)
        return btn
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
    aim     = { on = false, fov = 120, smooth = 0.3, part = "Head", maxDist = 500,
                visibleOnly = false, ignoreTeam = true, ignoreFriends = true, humanize = 0,
                target = nil, targetAt = 0, visCache = nil, conn = nil },
    assist  = { on = false, fov = 70, strength = 0.35, smooth = 0.45, part = "Head", maxDist = 300,
                visibleOnly = false, ignoreTeam = true, ignoreFriends = true, humanize = 0.2,
                firingOnly = false, target = nil, targetAt = 0, visCache = nil, conn = nil },
    scaffold = { on = false, grid = 4, extend = 1, delay = 0.12, mode = "Activate",
                 tower = true, safewalk = true, downward = true, cursor = true,
                 conn = nil, charConn = nil, lastPlace = 0, placed = 0 },
    silent  = { on = false, fov = 150, conn = nil },
    hitbox  = { on = false, size = 5, conn = nil, sizes = {} },
    esp     = {
        on = false, skel = true, conn = nil, gui = nil, objects = {}, skelFrames = {}, plConn = nil, remConn = nil,
        -- фильтры
        ignoreTeam = true, ignoreFriends = true, maxDist = 500, visibleOnly = false,
        -- что рисовать
        box = true, name = true, hp = true, dist = true,
        -- цвета (ключи из ESP_COLORS)
        colorBox = "Белый", colorSkel = "Голубой", colorText = "Серый", colorChams = "Голубой",
    },
    fly     = { on = false, speed = 50, conn = nil, bv = nil, bg = nil },
    noclip  = { on = false, conn = nil, burstUntil = 0, saved = {}, holdPart = nil, holdPos = nil, holdUntil = 0 },
    airstuck = { on = false, mode = "Packet", throttle = 10, maxHold = 20, lock = false,
                 conn = nil, charConn = nil, root = nil, hum = nil, cf = nil, platform = false,
                 net = false, froze = false, since = 0, stop = nil },
    ghost   = { on = false, conn = nil, charConn = nil, root = nil, hum = nil, camPos = nil,
                camCF = nil, camType = nil, mouse = nil, wasAnchored = false },
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

--===================  AIM ENGINE  (Aimbot + Aim Assist)  ===================
--  Два модуля на одном ядре:
--    Aimbot     — доводит камеру до цели полностью;
--    Aim Assist — тянет прицел к цели частично, не забирая контроль.
--  Считаем в yaw/pitch камеры, поэтому шаг не зависит от FPS и не дёргается
--  на больших углах (обычный Lerp по CFrame там заметно «залипает»).
--  Всё лежит в FEAT: у главного чанка лимит 200 локалов, а функций тут много.
local FEAT = {}

-- Пакетный Air Stuck: NetworkClient:SetOutgoingKBPSLimit под Plugin Security.
-- В executor'ах зовётся напрямую, иначе пробуем поднять identity. Движок
-- клампит значение в 10..10000, так что «полного нуля» нет — 10 кбит/с уже
-- почти не пропускает апдейты позиции.
FEAT.net = { MIN = 10, MAX = 10000 }

function FEAT.net.set(kbps)
    local ok, svc = pcall(function() return game:GetService("NetworkClient") end)
    if not ok or not svc then return false end
    local limit = math.clamp(kbps or FEAT.net.MIN, FEAT.net.MIN, FEAT.net.MAX)
    if pcall(function() svc:SetOutgoingKBPSLimit(limit) end) then return true end
    -- не хватило прав: пробуем из-под plugin/executor identity
    local getI = getthreadidentity
    local setI = setthreadidentity or set_thread_identity or (syn and syn.set_thread_identity)
    if type(setI) ~= "function" then return false end
    local prev = type(getI) == "function" and getI() or nil
    local done = false
    for _, id in ipairs({ 7, 8, 2 }) do
        if pcall(function()
            setI(id)
            svc:SetOutgoingKBPSLimit(limit)
        end) then
            done = true
            break
        end
    end
    if prev then pcall(function() setI(prev) end) end
    return done
end

do
    local A = {}
    FEAT.aim = A
    A.conn = nil
    A.friendCache = {}

    function A.wrapDeg(v)
        return ((v + 180) % 360) - 180
    end

    function A.dir(from, to)
        local d = to - from
        local m = d.Magnitude
        if m < 1e-4 then return nil end
        return Vector3.new(d.X / m, d.Y / m, d.Z / m)
    end

    function A.camAngles(cf)
        local look = cf and cf.LookVector
        if not look then return 0, 0 end
        return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
    end

    function A.anglesTo(from, to)
        local dir = A.dir(from, to)
        if not dir then return nil end
        return math.atan2(-dir.X, -dir.Z), math.asin(math.clamp(dir.Y, -1, 1))
    end

    function A.anglesToDir(yaw, pitch)
        local cp = math.cos(pitch)
        return Vector3.new(-math.sin(yaw) * cp, math.sin(pitch), -math.cos(yaw) * cp)
    end

    function A.sameTeam(plr)
        return LP.Team ~= nil and plr.Team ~= nil and plr.Team == LP.Team
    end

    function A.isFriend(plr)
        local cached = A.friendCache[plr]
        if cached ~= nil then return cached end
        local ok, res = pcall(function() return plr:IsFriendsWith(LP.UserId) end)
        local v = (ok and res) and true or false
        A.friendCache[plr] = v
        return v
    end

    function A.filtered(plr, cfg)
        if plr == LP then return true end
        if cfg.ignoreTeam and A.sameTeam(plr) then return true end
        if cfg.ignoreFriends and A.isFriend(plr) then return true end
        return false
    end

    -- луч камера -> точка: true, если ничего не мешает
    function A.visible(char, pos)
        local cam = workspace.CurrentCamera
        if not cam then return true end
        local ok, res = pcall(function()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local ignore = {}
            if char then table.insert(ignore, char) end
            if LP.Character then table.insert(ignore, LP.Character) end
            params.FilterDescendantsInstances = ignore
            local origin = cam.CFrame.Position
            local hit = workspace:Raycast(origin, pos - origin, params)
            return hit == nil
        end)
        if not ok then return true end
        return res
    end

    -- точка прицеливания: Head / Torso / Nearest (ближайшая к прицелу часть)
    function A.partOf(plr, mode, cam, cx, cy)
        local ch = plr.Character
        if not ch then return nil end
        local head = ch:FindFirstChild("Head")
        local torso = ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
        local root = ch:FindFirstChild("HumanoidRootPart")
        if mode == "Nearest" then
            local list = {}
            if head then table.insert(list, head) end
            if torso then table.insert(list, torso) end
            if root then table.insert(list, root) end
            local best, bestD = nil, math.huge
            for _, part in ipairs(list) do
                local d = math.huge
                local ok, sp, onScreen = pcall(function() return cam:WorldToViewportPoint(part.Position) end)
                if ok and onScreen then
                    d = math.sqrt((sp.X - cx) ^ 2 + (sp.Y - cy) ^ 2)
                end
                if d < bestD then best, bestD = part, d end
            end
            return best
        end
        if mode == "Torso" then return torso or root or head end
        return head or torso or root
    end

    -- ближайший к прицелу игрок в радиусе FOV, с фильтрами и гистерезисом
    function A.findTarget(cfg)
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local vp = cam.ViewportSize
        local cx = (vp and vp.X or 1920) / 2
        local cy = (vp and vp.Y or 1080) / 2
        local camPos = cam.CFrame.Position
        local now = os.clock()
        local best, bestScore, bestPos = nil, math.huge, nil

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and alive(plr) and not A.filtered(plr, cfg) then
                local part = A.partOf(plr, cfg.part, cam, cx, cy)
                if part then
                    local pos = part.Position
                    local d, dist = math.huge, math.huge
                    local ok, sp, onScreen = pcall(function() return cam:WorldToViewportPoint(pos) end)
                    if ok and onScreen then
                        d = math.sqrt((sp.X - cx) ^ 2 + (sp.Y - cy) ^ 2)
                    end
                    pcall(function() dist = (camPos - pos).Magnitude end)
                    if d <= (cfg.fov or 120) and dist <= (cfg.maxDist or 1000) then
                        local visOk = true
                        if cfg.visibleOnly then
                            cfg.visCache = cfg.visCache or {}
                            local cached = cfg.visCache[plr]
                            if cached and now - cached.at < 0.1 then
                                visOk = cached.ok
                            else
                                visOk = A.visible(plr.Character, pos)
                                cfg.visCache[plr] = { ok = visOk, at = now }
                            end
                        end
                        if visOk then
                            local score = d + dist * 0.02
                            -- текущая цель не проигрывает случайно соседу
                            if cfg.target == plr then score = score * 0.85 end
                            if score < bestScore then
                                best, bestScore, bestPos = plr, score, pos
                            end
                        end
                    end
                end
            end
        end
        return best, bestPos
    end

    function A.apply(cfg, mode, dt)
        local cam = workspace.CurrentCamera
        if not cam then return end

        local target, pos = A.findTarget(cfg)
        cfg.target = target
        if not target then return end
        cfg.targetAt = os.clock()

        local camPos = cam.CFrame.Position
        local curYaw, curPitch = A.camAngles(cam.CFrame)
        local desYaw, desPitch = A.anglesTo(camPos, pos)
        if not desYaw then return end

        -- человеческий шум: два синуса, чтобы не было идеально ровной линии
        local h = math.clamp(tonumber(cfg.humanize) or 0, 0, 1)
        if h > 0 then
            local t = os.clock()
            desYaw = desYaw + math.rad((math.sin(t * 3.1) * 0.30 + math.sin(t * 7.3) * 0.16) * h)
            desPitch = desPitch + math.rad((math.sin(t * 2.7) * 0.22 + math.cos(t * 5.1) * 0.10) * h)
        end

        local smooth = math.clamp(tonumber(cfg.smooth) or 0.3, 0.02, 1)
        -- 1 - (1 - smooth)^(dt*60): та же скорость, что при 60 FPS, на любом FPS
        local factor = 1 - (1 - smooth) ^ ((dt or 0.016) * 60)
        if mode == "assist" then
            factor = factor * math.clamp(tonumber(cfg.strength) or 0.4, 0.02, 1)
        end

        local dy = A.wrapDeg(math.deg(desYaw - curYaw))
        local dp = math.deg(desPitch - curPitch)
        local snap = (mode == "aim" and h <= 0) and 0.2 or 0.03
        local stepY = math.abs(dy) <= snap and dy or dy * factor
        local stepP = math.abs(dp) <= snap and dp or dp * factor

        local newYaw = curYaw + math.rad(stepY)
        local newPitch = math.clamp(curPitch + math.rad(stepP), -math.rad(89), math.rad(89))
        local dir = A.anglesToDir(newYaw, newPitch)
        pcall(function()
            cam.CFrame = CFrame.lookAt(camPos, camPos + dir)
        end)
    end

    function A.firing()
        local ok, res = pcall(function()
            return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        end)
        if ok then return res end
        return true
    end

    function A.loop(dt)
        if FZ.scaffold.on then return end  -- скаффолд забирает камеру себе
        local cfg, mode = nil, nil
        if FZ.aim.on then
            cfg, mode = FZ.aim, "aim"
        elseif FZ.assist.on then
            cfg, mode = FZ.assist, "assist"
            if cfg.firingOnly and not A.firing() then
                cfg.target = nil
                return
            end
        end
        if not cfg then return end
        A.apply(cfg, mode, dt)
    end

    function A.ensureLoop()
        if A.conn then return end
        A.conn = RunService.RenderStepped:Connect(function(dt)
            if not FZ.aim.on and not FZ.assist.on then
                if A.conn then
                    pcall(function() A.conn:Disconnect() end)
                    A.conn = nil
                end
                return
            end
            pcall(A.loop, dt)
        end)
    end

    function FEAT.setAimbot(on)
        FZ.aim.on = on and true or false
        FZ.aim.visCache = nil
        if not FZ.aim.on then
            FZ.aim.target = nil
        elseif FZ.assist.on then
            -- два аима на одной камере дерутся, аимбот главнее
            FZ.assist.on = false
            FZ.assist.target = nil
            local c = CONTROLS["Legitbot/Aim Assist/Enabled"]
            if c and c.set then pcall(function() c:set(false, true) end) end
        end
        if FZ.aim.on or FZ.assist.on then A.ensureLoop() end
    end

    function FEAT.setAssist(on)
        FZ.assist.on = on and true or false
        FZ.assist.visCache = nil
        if not FZ.assist.on then
            FZ.assist.target = nil
        elseif FZ.aim.on then
            FZ.aim.on = false
            FZ.aim.target = nil
            local c = CONTROLS["Ragebot/Aimbot/Enabled"]
            if c and c.set then pcall(function() c:set(false, true) end) end
        end
        if FZ.aim.on or FZ.assist.on then A.ensureLoop() end
    end
end

FEAT.aimParts = { "Head", "Torso", "Nearest" }

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
                FZ.silent.target = target
                FZ.silent.targetAt = os.clock()
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
                FZ.silent.target = target
                FZ.silent.targetAt = os.clock()
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

-- палитра ESP: в конфиге хранится имя цвета, сам Color3 берём отсюда
local ESP_COLORS = {
    ["Белый"]   = Color3.fromRGB(236, 244, 255),
    ["Серый"]   = Color3.fromRGB(150, 168, 190),
    ["Акцент"]  = Color3.fromRGB(150, 140, 255),
    ["Красный"] = Color3.fromRGB(235, 80, 95),
    ["Зелёный"] = Color3.fromRGB(95, 220, 140),
    ["Голубой"] = Color3.fromRGB(126, 206, 255),
    ["Жёлтый"]  = Color3.fromRGB(245, 215, 110),
    ["Розовый"] = Color3.fromRGB(240, 130, 190),
}
local ESP_COLOR_LIST = { "Белый", "Серый", "Акцент", "Красный", "Зелёный", "Голубой", "Жёлтый", "Розовый" }

local function espColor(name)
    return ESP_COLORS[name] or ESP_COLORS["Белый"]
end

-- свои / друзья: IsFriendsWith дорогой, поэтому кэшируем ответ на игрока
local espFriendCache = {}

local function espSameTeam(plr)
    local me, other = LP.Team, plr.Team
    return me ~= nil and other ~= nil and other == me
end

local function espIsFriend(plr)
    local cached = espFriendCache[plr]
    if cached ~= nil then return cached end
    local ok, res = pcall(function() return plr:IsFriendsWith(LP.UserId) end)
    local v = (ok and res) and true or false
    espFriendCache[plr] = v
    return v
end

local function espHiddenByFilter(plr)
    local esp = FZ.esp
    if plr == LP then return true end
    if esp.ignoreTeam and espSameTeam(plr) then return true end
    if esp.ignoreFriends and espIsFriend(plr) then return true end
    return false
end

-- only-visible: луч из камеры в голову; свой персонаж и цель исключены из фильтра
local function espVisible(char, pos)
    local cam = workspace.CurrentCamera
    if not cam then return true end
    local ok, res = pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = { char }
        if LP.Character then table.insert(ignore, LP.Character) end
        params.FilterDescendantsInstances = ignore
        local origin = cam.CFrame.Position
        local hit = workspace:Raycast(origin, pos - origin, params)
        return hit == nil
    end)
    if not ok then return true end  -- мок/старый executor без Raycast: считаем видимым
    return res
end

-- цвет полоски HP: зелёный (1.0) -> красный (0.0)
local function hpColor(r)
    return Color3.fromRGB(235 - 140 * r, 80 + 135 * r, 80 + 45 * r)
end

local function espLine(parent, color, z)
    return new("Frame", {
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ZIndex = z or 4,
        Visible = false,
    }, parent)
end

local function createESP(plr)
    if plr == LP or FZ.esp.objects[plr] then return end
    local g = espGui()
    local data = { box = {}, corners = {} }
    FZ.esp.objects[plr] = data

    -- мягкая подсветка модели, без кричащих цветов
    data.highlight = new("Highlight", {
        FillColor = espColor(FZ.esp.colorChams),
        OutlineColor = espColor(FZ.esp.colorChams),
        FillTransparency = 0.85,
        OutlineTransparency = 0.6,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Enabled = false,
    }, g)

    -- тонкая рамка (4 линии)
    for i = 1, 4 do data.box[i] = espLine(g, ESP_FRAME, 4) end
    -- уголки (8 коротких линий)
    for i = 1, 8 do data.corners[i] = espLine(g, ESP_FRAME, 5) end

    -- полоска здоровья слева
    data.hpBg = espLine(g, Color3.fromRGB(6, 9, 13), 4)
    data.hpBg.BackgroundTransparency = 0.3
    data.hpFill = espLine(g, hpColor(1), 5)

    local bb = new("BillboardGui", {
        Name = "SpermaHubESPInfo",
        Size = UDim2.fromOffset(220, 44),
        StudsOffset = Vector3.new(0, 2.6, 0),
        AlwaysOnTop = true,
    }, g)

    data.nameLabel = txt(bb, plr.Name, {
        Size = UDim2.new(1, 0, 0, 20),
        Font = F.bold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(242, 247, 255),
        TextStrokeTransparency = 0.25,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    data.infoLabel = txt(bb, "", {
        Position = UDim2.new(0, 0, 0, 19),
        Size = UDim2.new(1, 0, 0, 16),
        Font = F.med,
        TextSize = 12,
        TextColor3 = ESP_TEXT,
        TextStrokeTransparency = 0.45,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    data.billboard = bb
end

local function removeESP(plr)
    local data = FZ.esp.objects[plr]
    if not data then return end
    local loose = { data.highlight, data.billboard, data.hpBg, data.hpFill }
    for _, obj in ipairs(data.box) do table.insert(loose, obj) end
    for _, obj in ipairs(data.corners) do table.insert(loose, obj) end
    for _, obj in ipairs(loose) do
        if obj then pcall(function() obj:Destroy() end) end
    end
    FZ.esp.objects[plr] = nil
end

local function hideESP(data)
    data.hidden = true
    for _, o in ipairs(data.box) do o.Visible = false end
    for _, o in ipairs(data.corners) do o.Visible = false end
    if data.hpBg then data.hpBg.Visible = false end
    if data.hpFill then data.hpFill.Visible = false end
    if data.highlight then
        data.highlight.Adornee = nil
        data.highlight.Enabled = false
    end
    if data.billboard then data.billboard.Adornee = nil end
end

local function updateESP()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local esp = FZ.esp
    local camPos = cam.CFrame.Position
    local boxColor = espColor(esp.colorBox)
    local textColor = espColor(esp.colorText)

    for plr, data in pairs(FZ.esp.objects) do
        local ch = plr.Character
        local head = ch and ch:FindFirstChild("Head")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local headPos = head and head.Position or (hrp and hrp.Position + Vector3.new(0, 1.5, 0))
        local dist = hrp and (camPos - hrp.Position).Magnitude or nil

        local draw = ch ~= nil and alive(plr) and not espHiddenByFilter(plr)
        if draw and dist and dist > esp.maxDist then draw = false end

        -- «только видимые»: рейкаст не чаще ~8 раз в секунду на игрока
        if draw and esp.visibleOnly and headPos then
            local now = os.clock()
            if not data.visCheck or now >= data.visCheck then
                data.visOk = espVisible(ch, headPos)
                data.visCheck = now + 0.12
            end
            if not data.visOk then draw = false end
        end

        if not draw then
            hideESP(data)
        elseif headPos and hrp then
            if data.highlight then
                data.highlight.Adornee = ch
                data.highlight.FillColor = espColor(esp.colorChams)
                data.highlight.OutlineColor = espColor(esp.colorChams)
                data.highlight.Enabled = true
            end

            local topV, topOn = cam:WorldToViewportPoint(headPos + Vector3.new(0, 0.65, 0))
            local botV, botOn = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            if topOn and botOn then
                local height = math.abs(botV.Y - topV.Y)
                local width = height * 0.5
                local x, y = topV.X - width / 2, topV.Y
                local right, bottom = x + width, y + height

                local fade = math.clamp(1 - (dist or 0) / 400, 0.35, 1)
                local frameA = 0.7 + (1 - fade) * 0.2
                local cornerA = 0.15 + (1 - fade) * 0.3

                if esp.box then
                    local edges = {
                        { x, y, width, 1 }, { x, bottom, width, 1 },
                        { x, y, 1, height }, { right, y, 1, height },
                    }
                    for i, e in ipairs(edges) do
                        local line = data.box[i]
                        line.Size = UDim2.new(0, e[3], 0, e[4])
                        line.Position = UDim2.new(0, e[1], 0, e[2])
                        line.BackgroundColor3 = boxColor
                        line.BackgroundTransparency = frameA
                        line.Visible = true
                    end

                    local arm = math.clamp(height * 0.16, 6, 16)
                    local corners = {
                        { x, y, arm, 1 }, { x, y, 1, arm },
                        { right - arm, y, arm, 1 }, { right - 1, y, 1, arm },
                        { x, bottom - 1, arm, 1 }, { x, bottom - arm, 1, arm },
                        { right - arm, bottom - 1, arm, 1 }, { right - 1, bottom - arm, 1, arm },
                    }
                    for i, c in ipairs(corners) do
                        local line = data.corners[i]
                        line.Size = UDim2.new(0, c[3], 0, c[4])
                        line.Position = UDim2.new(0, c[1], 0, c[2])
                        line.BackgroundColor3 = boxColor
                        line.BackgroundTransparency = cornerA
                        line.Visible = true
                    end
                else
                    for _, line in ipairs(data.box) do line.Visible = false end
                    for _, line in ipairs(data.corners) do line.Visible = false end
                end

                if hum and esp.hp then
                    local ratio = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                    data.hpBg.Size = UDim2.new(0, 3, 0, height)
                    data.hpBg.Position = UDim2.new(0, x - 7, 0, y)
                    data.hpBg.Visible = true
                    data.hpFill.Size = UDim2.new(0, 3, 0, height * ratio)
                    data.hpFill.Position = UDim2.new(0, x - 7, 0, bottom - height * ratio)
                    data.hpFill.BackgroundColor3 = hpColor(ratio)
                    data.hpFill.Visible = true
                else
                    data.hpBg.Visible = false
                    data.hpFill.Visible = false
                end

                local info = {}
                if hum and esp.hp then table.insert(info, string.format("%d HP", math.floor(hum.Health))) end
                if esp.dist and dist then table.insert(info, string.format("%dm", math.floor(dist))) end
                if data.infoLabel then
                    data.infoLabel.Text = table.concat(info, "  \u{2022}  ")
                    data.infoLabel.Visible = #info > 0
                    data.infoLabel.TextColor3 = textColor
                end
                if data.nameLabel then
                    data.nameLabel.Visible = esp.name
                    data.nameLabel.Text = plr.Name
                    data.nameLabel.TextColor3 = textColor
                end

                if data.billboard then data.billboard.Adornee = head or hrp end
                data.hidden = false
            else
                hideESP(data)
            end
        else
            hideESP(data)
        end
    end
end

local function drawSkeleton()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local skelColor = espColor(FZ.esp.colorSkel)
    for plr, data in pairs(FZ.esp.objects) do
        local ch = plr.Character
        if data.hidden then
            for _, f in ipairs(FZ.esp.skelFrames[plr] or {}) do f.Visible = false end
        elseif ch and alive(plr) then
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
                                BackgroundColor3 = ESP_SKEL,
                                BackgroundTransparency = 0.3,
                                BorderSizePixel = 0,
                                ZIndex = 3,
                            }, g)
                        end
                        local f = frames[i]
                        f.BackgroundColor3 = skelColor
                        local dx, dy = v2.X - v1.X, v2.Y - v1.Y
                        f.Size = UDim2.new(0, math.sqrt(dx * dx + dy * dy), 0, 1)
                        f.Position = UDim2.new(0, v1.X, 0, v1.Y)
                        local angle = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
                        f.Rotation = math.deg(angle)
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
        if FZ.esp.plConn then pcall(function() FZ.esp.plConn:Disconnect() end) FZ.esp.plConn = nil end
        if FZ.esp.remConn then pcall(function() FZ.esp.remConn:Disconnect() end) FZ.esp.remConn = nil end
        for plr in pairs(FZ.esp.objects) do removeESP(plr) end
        FZ.esp.objects = {}
        for _, frames in pairs(FZ.esp.skelFrames) do
            for _, f in ipairs(frames) do pcall(function() f:Destroy() end) end
        end
        FZ.esp.skelFrames = {}
        return
    end

    espGui()
    espFriendCache = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then createESP(plr) end
    end

    -- без этого ESP не появлялся у тех, кто зашёл уже после включения
    if not FZ.esp.plConn then
        FZ.esp.plConn = Players.PlayerAdded:Connect(function(plr)
            if FZ.esp.on and plr ~= LP then createESP(plr) end
        end)
        FZ.esp.remConn = Players.PlayerRemoving:Connect(function(plr)
            espFriendCache[plr] = nil
            removeESP(plr)
            for _, f in ipairs(FZ.esp.skelFrames[plr] or {}) do pcall(function() f:Destroy() end) end
            FZ.esp.skelFrames[plr] = nil
        end)
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
--  Гасит коллизии у всех частей персонажа и держит их выключенными
--  (Stepped), поэтому из стен и пола не выталкивает. Что было включено —
--  запоминается и возвращается при выключении.
local function noclipRestore()
    for part, canCollide in pairs(FZ.noclip.saved) do
        pcall(function() part.CanCollide = canCollide end)
    end
    FZ.noclip.saved = {}
end

local function noclipApply()
    local ch = LP.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return end
    local saved = FZ.noclip.saved
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            if saved[p] == nil then saved[p] = true end
            pcall(function() p.CanCollide = false end)
        end
    end
end

local function noclipStopLoop()
    if FZ.noclip.conn then
        pcall(function() FZ.noclip.conn:Disconnect() end)
        FZ.noclip.conn = nil
    end
end

local function noclipStep()
    local now = os.clock()
    local hold = FZ.noclip.holdPart
    if hold then
        if now < FZ.noclip.holdUntil then
            pcall(function() hold.CFrame = CFrame.new(FZ.noclip.holdPos) end)
        else
            FZ.noclip.holdPart = nil
        end
    end
    if FZ.noclip.on or now < FZ.noclip.burstUntil then
        noclipApply()
    else
        noclipRestore()
        noclipStopLoop()
    end
end

local function noclipLoop()
    if FZ.noclip.conn then return end
    FZ.noclip.conn = RunService.Stepped:Connect(noclipStep)
end

-- короткое окно без коллизий + удержание точки: телепорт не откидывает назад
local function noclipTeleport(part, pos, seconds)
    local t = os.clock() + (seconds or 0.25)
    FZ.noclip.holdPart = part
    FZ.noclip.holdPos = pos
    FZ.noclip.holdUntil = t
    if t > FZ.noclip.burstUntil then FZ.noclip.burstUntil = t end
    noclipLoop()
    noclipApply()
end

local function setNoclip(on)
    FZ.noclip.on = on and true or false
    if FZ.noclip.on then
        noclipLoop()
        noclipApply()
    else
        FZ.noclip.burstUntil = 0
        FZ.noclip.holdPart = nil
        noclipRestore()
        noclipStopLoop()
    end
end

--===================  AIR STUCK  ===================
--  Два режима (Air Stuck Mode):
--   Physics — как было: каждый Stepped возвращаем сохранённый CFrame, гасим
--             скорость, PlatformStand не даёт хуманоиду шагать. Тело прибито
--             к точке и локально, и у сервера.
--   Packet  — лаг-свитч, как в майнкрафте: режем ИСХОДЯЩИЙ трафик через
--             NetworkClient:SetOutgoingKBPSLimit. Клиент продолжает жить
--             (двигаешься, крутишь камеру, бьёшь), но апдейты не доходят, и
--             для других ты стоишь где стоял. Выключил — трафик пошёл, и
--             тебя дёргает туда, где ты на самом деле стоишь. Нет доступа к
--             NetworkClient — откатываемся на локальный фриз тела.
--  Max Hold сам отпускает трафик, иначе сервер кикнет за потерю связи.
local function airstuckSnap(holdBody)
    local A = FZ.airstuck
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return false end
    A.hum = hum
    A.root = root
    A.platform = hum.PlatformStand and true or false
    A.cf = root.CFrame
    if holdBody then
        A.froze = true
        pcall(function() hum.PlatformStand = true end)
    end
    return true
end

local function airstuckStep()
    local A = FZ.airstuck
    if not A.on then return end

    if A.mode == "Packet" then
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local release = (not hum) or hum.Health <= 0
        if A.maxHold and A.maxHold > 0 and os.clock() - A.since >= A.maxHold then
            release = true
        end
        if release then
            if A.stop then A.stop(false) end  -- сами отпускаем трафик
            return
        end
        if A.lock then
            -- тело тоже держим, но без PlatformStand: хуманоид должен слушаться
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if root and A.cf then
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    root.CFrame = A.cf
                end)
            end
        end
        return
    end

    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then
        -- померли или персонаж сменился: ждём CharacterAdded
        A.root = nil
        A.cf = nil
        return
    end
    if A.root ~= root or not A.cf then
        airstuckSnap(true)
        return
    end
    if not hum.PlatformStand then pcall(function() hum.PlatformStand = true end) end
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = A.cf
    end)
end

local function setAirstuck(on)
    local A = FZ.airstuck
    A.on = on and true or false
    if A.conn then
        pcall(function() A.conn:Disconnect() end)
        A.conn = nil
    end
    if A.charConn then
        pcall(function() A.charConn:Disconnect() end)
        A.charConn = nil
    end

    if not A.on then
        -- трафик возвращаем первым делом: иначе сервер так и не узнает, где мы
        if A.net then
            FEAT.net.set(FEAT.net.MAX)
            A.net = false
        end
        if A.froze then
            if A.hum then
                -- если включён Fly, PlatformStand ему нужен — не гасим
                pcall(function() A.hum.PlatformStand = FZ.fly.on and true or A.platform end)
            end
            if A.root then
                pcall(function()
                    A.root.AssemblyLinearVelocity = Vector3.zero
                    A.root.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        -- Max Hold гасит фичу сам — синхронизируем тогл, чтобы не висел включённым
        local c = CONTROLS["Miscellaneous/Main/Air Stuck"]
        if c and c.get and c:get() then pcall(function() c:set(false, true) end) end
        A.root = nil
        A.hum = nil
        A.cf = nil
        A.platform = false
        A.froze = false
        A.since = 0
        return
    end

    -- перезапуск режима на ходу: снимаем прошлый фриз и возвращаем трафик
    if A.net then
        FEAT.net.set(FEAT.net.MAX)
        A.net = false
    end
    if A.froze and A.hum then
        pcall(function() A.hum.PlatformStand = A.platform end)
    end
    A.froze = false

    A.since = os.clock()
    if A.mode == "Packet" then
        A.net = FEAT.net.set(A.throttle)
        airstuckSnap(false)
        if not A.net then
            warn("[SpermaHub] Air Stuck: NetworkClient недоступен — держу тело локально")
            if A.hum then pcall(function() A.hum.PlatformStand = true end) end
            A.froze = true
        end
    else
        airstuckSnap(true)
    end

    A.stop = setAirstuck  -- шаг сам отпускает по Max Hold
    A.conn = RunService.Stepped:Connect(airstuckStep)
    A.charConn = LP.CharacterAdded:Connect(function()
        task.wait(0.15)  -- ждём, пока соберётся персонаж
        if not A.on then return end
        if A.mode == "Packet" then
            airstuckSnap(false)
            if not A.net and A.hum then
                pcall(function() A.hum.PlatformStand = true end)
                A.froze = true
            end
        else
            airstuckSnap(true)
        end
    end)
end

--===================  GHOST STAND (server freeze)  ===================
--  Для других игроков ты стоишь на месте, пока камера летает; выключил —
--  тело появилось там, куда прилетел. Работает только через якорь: клиент —
--  сетевой владелец персонажа, его CFrame/Anchored уходят на сервер, и
--  заякоренная фигура стоит для всех. Настоящий десинк «двигаюсь локально,
--  серверу позицию не отдаю» — это lag switch (блокировка пакетов), в чистом
--  Luau недоступен.
local GHOST_CAM = { yaw = 0, pitch = 0, speed = 60 }
local GHOST_EYE = 1.5  -- камера висит выше HRP примерно столько

local function ghostCamFromLook(look)
    if not look then return end
    GHOST_CAM.yaw = math.atan2(-look.X, -look.Z)
    GHOST_CAM.pitch = math.asin(math.clamp(look.Y, -1, 1))
end

local function ghostStep(dt)
    local G = FZ.ghost
    if not G.on then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local delta
    pcall(function() delta = UIS:GetMouseDelta() end)
    if delta then
        GHOST_CAM.yaw = GHOST_CAM.yaw - delta.X * 0.003
        GHOST_CAM.pitch = math.clamp(GHOST_CAM.pitch - delta.Y * 0.003, -1.45, 1.45)
    end

    local yaw, pitch = GHOST_CAM.yaw, GHOST_CAM.pitch
    local fwd = Vector3.new(-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
    local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
    local d = Vector3.new(0, 0, 0)
    if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + fwd end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - fwd end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + right end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - right end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0, 1, 0) end

    local pos = G.camPos or (cam.CFrame and cam.CFrame.Position) or Vector3.new(0, 0, 0)
    if d.Magnitude > 0 then
        pos = pos + d.Unit * GHOST_CAM.speed * (dt or 0.016)
    end
    G.camPos = pos
    G.camCF = CFrame.new(pos) * (CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0))
    pcall(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = G.camCF
    end)
end

-- заякорить текущее тело и отцепить камеру
local function ghostAttach()
    local G = FZ.ghost
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end
    G.root = root
    G.hum = hum
    G.wasAnchored = root.Anchored and true or false
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        root.Anchored = true
    end)
    local cam = workspace.CurrentCamera
    if cam then
        G.camPos = cam.CFrame and cam.CFrame.Position
        pcall(function() ghostCamFromLook(cam.CFrame.LookVector) end)
    end
end

local function setGhostFreeze(on)
    local G = FZ.ghost
    G.on = on and true or false
    if G.conn then pcall(function() G.conn:Disconnect() end) G.conn = nil end
    if G.charConn then pcall(function() G.charConn:Disconnect() end) G.charConn = nil end

    local cam = workspace.CurrentCamera

    if not G.on then
        if cam then
            pcall(function()
                if G.hum then cam.CameraSubject = G.hum end
                cam.CameraType = G.camType or Enum.CameraType.Custom
            end)
        end
        pcall(function()
            UIS.MouseBehavior = G.mouse or Enum.MouseBehavior.Default
            UIS.MouseIconEnabled = true
        end)

        local root, hum, dest = G.root, G.hum, G.camPos
        if root and hum and hum.Health > 0 and dest then
            -- ставим тело в точку камеры, пока ещё заякорено, и снимаем якорь
            local target = dest - Vector3.new(0, GHOST_EYE, 0)
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                root.CFrame = CFrame.new(target)
            end)
            noclipTeleport(root, target, 0.25)
            pcall(function() root.Anchored = G.wasAnchored and true or false end)
        end

        G.root, G.hum, G.camPos, G.camCF = nil, nil, nil, nil
        return
    end

    -- Air Stuck каждый шаг возвращает CFrame и сорвал бы якорь
    if FZ.airstuck.on then
        setAirstuck(false)
        local c = CONTROLS["Miscellaneous/Main/Air Stuck"]
        if c and c.set then pcall(function() c:set(false, true) end) end
    end

    if cam then
        G.camType = cam.CameraType
        G.mouse = UIS.MouseBehavior
    end
    ghostAttach()
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        UIS.MouseIconEnabled = false
    end)
    G.conn = RunService.RenderStepped:Connect(ghostStep)
    G.charConn = LP.CharacterAdded:Connect(function()
        task.wait(0.2)
        if FZ.ghost.on then ghostAttach() end
    end)
end

--===================  SCAFFOLD  ===================
--  Порт rich Scaffold.java под Roblox. В Minecraft блок уходит пакетом, здесь
--  его ставит инструмент самой игры, поэтому шаги такие:
--    1) ищем клетку сетки без опоры (под ногами -> углы -> вперёд -> вниз)
--    2) ищем рядом поверхность, по которой можно поставить блок
--    3) ведём камеру в эту точку (и курсор, если executor умеет mousemoverel)
--    4) когда камера уже смотрит в точку — Tool:Activate() или mouse1click()
--  SafeWalk/Tower/Extend/Downward перенесены по смыслу из Java-версии.
local SCF = {}

do
    function SCF.ray(from, to)
        local ok, hit = pcall(function()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local ignore = {}
            if LP.Character then table.insert(ignore, LP.Character) end
            params.FilterDescendantsInstances = ignore
            return workspace:Raycast(from, to - from, params)
        end)
        if not ok then return nil end
        return hit
    end

    function SCF.support(pos)
        return SCF.ray(pos + Vector3.new(0, 3, 0), pos - Vector3.new(0, 9, 0)) ~= nil
    end

    -- клетка, где нет пола: сначала под ногами, потом углы, вниз и вперёд
    function SCF.cell(root, hum)
        local S = FZ.scaffold
        local g = S.grid or 4
        local p = root.Position
        local half = 1
        pcall(function() if root.Size then half = root.Size.Y * 0.5 end end)
        local belowY = p.Y - half - 0.5

        local cells = { Vector3.new(p.X, belowY, p.Z) }
        local r = g * 0.45
        table.insert(cells, Vector3.new(p.X + r, belowY, p.Z + r))
        table.insert(cells, Vector3.new(p.X - r, belowY, p.Z + r))
        table.insert(cells, Vector3.new(p.X + r, belowY, p.Z - r))
        table.insert(cells, Vector3.new(p.X - r, belowY, p.Z - r))

        if S.downward and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            table.insert(cells, Vector3.new(p.X, belowY - g * 0.5, p.Z))
        end

        local mx, mz = 0, 0
        local md = hum and hum.MoveDirection
        if md then mx, mz = md.X, md.Z end
        local flat = math.sqrt(mx * mx + mz * mz)
        if flat < 0.05 then
            local v = root.AssemblyLinearVelocity
            if v then
                mx, mz = v.X, v.Z
                flat = math.sqrt(mx * mx + mz * mz)
            end
        end
        if flat > 0.05 then
            mx, mz = mx / flat, mz / flat
            for i = 1, (S.extend or 0) do
                table.insert(cells, Vector3.new(p.X + mx * g * i, belowY, p.Z + mz * g * i))
            end
        end

        for _, c in ipairs(cells) do
            if not SCF.support(c) then return c end
        end
        return nil
    end

    -- точка, по которой можно поставить блок рядом с пустой клеткой
    function SCF.point(cell)
        local g = FZ.scaffold.grid or 4
        local from = cell + Vector3.new(0, g * 0.1, 0)
        local dirs = {
            Vector3.new(0, -g, 0), Vector3.new(0, g, 0),
            Vector3.new(-g, 0, 0), Vector3.new(g, 0, 0),
            Vector3.new(0, 0, -g), Vector3.new(0, 0, g),
        }
        local best, bestDist = nil, math.huge
        for _, d in ipairs(dirs) do
            local hit = SCF.ray(from, from + d)
            if hit and hit.Position then
                local dist = (hit.Position - from).Magnitude
                if dist > 0.2 and dist < bestDist then
                    best, bestDist = hit.Position, dist
                end
            end
        end
        if not best then
            local top = cell + Vector3.new(0, g * 2, 0)
            local hit = SCF.ray(top, cell - Vector3.new(0, g * 2, 0))
            if hit and hit.Position then best = hit.Position end
        end
        return best
    end

    -- SafeWalk: нет пола впереди — гасим шаг, чтобы не улететь с края
    function SCF.safeWalk(root)
        local v = root.AssemblyLinearVelocity
        if not v then return end
        local flat = math.sqrt(v.X * v.X + v.Z * v.Z)
        if flat < 1 then return end
        local ahead = root.Position + Vector3.new(v.X / flat, 0, v.Z / flat) * ((FZ.scaffold.grid or 4) * 0.6)
        if SCF.support(ahead) then return end
        pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0) end)
    end

    -- камера сверху-сзади, смотрит в точку установки
    function SCF.camera(root, point, dt)
        local cam = workspace.CurrentCamera
        if not cam then return end
        local fx, fz = 0, -1
        local look = root.CFrame and root.CFrame.LookVector
        if look then
            local m = math.sqrt(look.X * look.X + look.Z * look.Z)
            if m > 0.1 then fx, fz = look.X / m, look.Z / m end
        end
        local g = FZ.scaffold.grid or 4
        local desired = root.Position - Vector3.new(fx, 0, fz) * (g * 2.2) + Vector3.new(0, g * 2.2 + 6, 0)
        local from = cam.CFrame.Position
        local a = 1 - (1 - 0.3) ^ ((dt or 0.016) * 60)
        local camPos = from + (desired - from) * a
        local yaw, pitch = FEAT.aim.anglesTo(camPos, point)
        if not yaw then return end
        local dir = FEAT.aim.anglesToDir(yaw, pitch)
        pcall(function()
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.lookAt(camPos, camPos + dir)
        end)
    end

    -- курсор в точку установки: нужен mousemoverel от executor'а
    function SCF.cursorTo(cam, point)
        local fn
        pcall(function() fn = getgenv and getgenv().mousemoverel or nil end)
        if type(fn) ~= "function" then
            pcall(function() fn = mousemoverel end)
        end
        if type(fn) ~= "function" then return false end
        local ok, sp, onScreen = pcall(function() return cam:WorldToScreenPoint(point) end)
        if not ok or not onScreen then return false end
        local mouse
        pcall(function() mouse = LP:GetMouse() end)
        if not mouse then return false end
        local dx = sp.X - (mouse.X or 0)
        local dy = sp.Y - (mouse.Y or 0)
        if math.abs(dx) < 1 and math.abs(dy) < 1 then return true end
        pcall(fn, dx, dy)
        return true
    end

    function SCF.tool()
        local ch = LP.Character
        if not ch then return nil end
        return ch:FindFirstChildOfClass("Tool")
    end

    function SCF.fire(tool, cam, point)
        local S = FZ.scaffold
        if S.cursor then pcall(SCF.cursorTo, cam, point) end
        if S.mode == "Click" then
            local click = nil
            pcall(function() click = mouse1click end)
            if type(click) == "function" then
                pcall(click)
                return true
            end
        end
        return pcall(function() tool:Activate() end)
    end

    function SCF.step(dt)
        local S = FZ.scaffold
        if not S.on then return end
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health <= 0 then return end

        if S.safewalk then SCF.safeWalk(root) end
        if S.tower and UIS:IsKeyDown(Enum.KeyCode.Space) then
            pcall(function() hum.Jump = true end)
        end

        local cell = SCF.cell(root, hum)
        S.cell = cell
        if not cell then return end
        local point = SCF.point(cell)
        S.point = point
        if not point then return end

        SCF.camera(root, point, dt)

        if os.clock() - S.lastPlace < (S.delay or 0.12) then return end
        local cam = workspace.CurrentCamera
        if not cam then return end

        -- ставим только когда камера уже смотрит в точку (как isLookingAtHitVec)
        local yaw, pitch = FEAT.aim.anglesTo(cam.CFrame.Position, point)
        if not yaw then return end
        local cy, cp = FEAT.aim.camAngles(cam.CFrame)
        if math.abs(FEAT.aim.wrapDeg(math.deg(yaw - cy))) > 4
            or math.abs(math.deg(pitch - cp)) > 4 then return end

        local tool = SCF.tool()
        if not tool then return end
        if SCF.fire(tool, cam, point) then
            S.lastPlace = os.clock()
            S.placed = (S.placed or 0) + 1
        end
    end

    function FEAT.setScaffold(on)
        local S = FZ.scaffold
        S.on = on and true or false
        if S.conn then pcall(function() S.conn:Disconnect() end) S.conn = nil end
        if S.charConn then pcall(function() S.charConn:Disconnect() end) S.charConn = nil end

        local cam = workspace.CurrentCamera
        if not S.on then
            if cam then
                pcall(function()
                    cam.CameraType = S.camType or Enum.CameraType.Custom
                    if S.camSubject then cam.CameraSubject = S.camSubject end
                end)
            end
            pcall(function() UIS.MouseBehavior = S.mouse or Enum.MouseBehavior.Default end)
            S.cell, S.point, S.camType, S.camSubject, S.mouse = nil, nil, nil, nil, nil
            return
        end

        if cam then
            S.camType = cam.CameraType
            S.camSubject = cam.CameraSubject
        end
        pcall(function() S.mouse = UIS.MouseBehavior end)
        pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
        S.lastPlace = 0

        if not SCF.tool() then
            notify("Scaffold: возьми инструмент, которым ставишь блоки")
        end

        S.conn = RunService.RenderStepped:Connect(function(dt)
            pcall(SCF.step, dt)
        end)
        S.charConn = LP.CharacterAdded:Connect(function()
            task.wait(0.15)
            if FZ.scaffold.on then S.lastPlace = 0 end
        end)
    end
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
    pcall(function() FEAT.setAimbot(false) end)
    pcall(function() FEAT.setAssist(false) end)
    pcall(function() setSilentAim(false) end)
    pcall(function() setHitbox(false) end)
    pcall(function() setESP(false) end)
    pcall(function() setFly(false) end)
    pcall(function() setNoclip(false) end)
    pcall(function() setAirstuck(false) end)
    pcall(function() setGhostFreeze(false) end)
    pcall(function() FEAT.setScaffold(false) end)
    pcall(function() setClickTp(false) end)
    pcall(function() setWalkSpeed(false) end)
    if FZ.esp.gui then pcall(function() FZ.esp.gui:Destroy() end) FZ.esp.gui = nil end
end

--=================================================================
--  HUD  (порт Interface.java, стиль Quick)
--=================================================================
--  Из исходников перенесено:
--    Interface.java — состав и дефолты элементов, фиксированные якоря
--                     (нотификации/ХП/скорость/хотбар), драг элементов,
--                     контекстное меню элемента (фон / блюр / от темы),
--                     порог оповещения о ХП, стиль "Quick".
--    Fonts.java + bold/quick/icons_nurik.json — MSDF-атласы. Самих PNG
--                     в архиве нет, поэтому шрифт — готика Roblox, а
--                     иконки — глифы/примитивы из ICONS выше.
--
--  Замены майнкрафтовых данных на роблоксовые:
--    Ticks          -> частота Heartbeat (TPS сервера Roblox не отдаёт)
--    TotemCounter   -> счётчик сейвов: ХП упало ниже 25% и вернулось выше 60%
--    Potions        -> активные функции хаба (Fly, Noclip, Aimbot, ...)
--    StaffList      -> создатель плейса / админы группы (rank >= 200)
--    MediaPlayer    -> Sound, который сейчас играет
--    Hotbar         -> инструменты из Backpack, 1..9
--    Cooldowns      -> HUD:AddCooldown(name, sec) + атрибут Cooldown у инструмента
--
--  API: getgenv().SpermaHubHUD
--    SpermaHubHUD.SetEnabled(id, on) / .IsEnabled(id) / .List()
--    .SetScale(k) / .SetLowHp(n) / .SetBgAlpha(a) / .SetHideInMenu(b)
--    .ResetPositions() / .Rebuild() / .Destroy()
--    .Push(text) / .AddBuff(name, sec) / .AddCooldown(name, sec)
--    .AddKeybind(key, label) / .SetStaff(userId, rank) / .SetTarget(player)
--=================================================================
local HUD = {
    gui = nil,
    root = nil,
    alive = true,
    openedMenu = false,
    scale = 1,
    bgAlpha = 0.30,
    lowHp = 30,
    hideInMenu = true,
    fps = 60,
    ping = 0,
    elements = {},
    conns = {},
    renderConn = nil,
    buffs = {},
    cooldowns = {},
    keybinds = {},
    staffIds = {},
    saves = 0,
    lowFlag = false,
    target = nil,
    state = { on = {}, pos = {}, flags = {} },
}

local HUD_FILE = "spermahub_config.json"

local HUD_DEFS = {
    { id = "watermark",     label = "Ватермарка",          on = true, x = 0.992, y = 0.028, ax = 1,   ay = 0 },
    { id = "arraylist",     label = "Список модулей",      on = true, x = 0.992, y = 0.048, ax = 1,   ay = 0, noBg = true },
    { id = "target",        label = "Активный таргет",     on = true, x = 0.014, y = 0.300, ax = 0,   ay = 0 },
    { id = "keybinds",      label = "Привязанные модули",  on = true, x = 0.014, y = 0.440, ax = 0,   ay = 0 },
    { id = "staff",         label = "Активные модераторы", on = true, x = 0.014, y = 0.560, ax = 0,   ay = 0 },
    { id = "potions",       label = "Бафы",                on = true, x = 0.014, y = 0.660, ax = 0,   ay = 0 },
    { id = "media",         label = "MediaPlayer",         on = true, x = 0.014, y = 0.780, ax = 0,   ay = 0 },
    { id = "ticks",         label = "Тики",                on = true, x = 0.500, y = 0.048, ax = 0.5, ay = 0 },
    { id = "ping",          label = "Пинг",                on = true, x = 0.500, y = 0.082, ax = 0.5, ay = 0 },
    { id = "speed",         label = "Скорость",            on = true, x = 0.500, y = 0.545, ax = 0.5, ay = 0 },
    { id = "totems",        label = "Счетчик сейвов",      on = true, x = 0.500, y = 0.585, ax = 0.5, ay = 0 },
    { id = "cooldowns",     label = "Кулдауны",            on = true, x = 0.992, y = 0.720, ax = 1,   ay = 0 },
    { id = "notifications", label = "Нотификации",         on = true, x = 0.500, y = 0.640, ax = 0.5, ay = 0, noBg = true },
    { id = "lowhp",         label = "Оповещение о хп",     on = true, x = 0,     y = 0,     ax = 0,   ay = 0, noBg = true },
}

local DEF_BY_ID = {}
for _, d in ipairs(HUD_DEFS) do
    DEF_BY_ID[d.id] = d
    HUD.state.on[d.id] = d.on
    HUD.state.pos[d.id] = { x = d.x, y = d.y }
    HUD.state.flags[d.id] = { bg = true, blur = true, theme = false }
end

local function hpClamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function hpScale(n)
    return math.max(1, math.floor(n * HUD.scale + 0.5))
end

local function hpColor(f)
    f = hpClamp(f, 0, 1)
    local r = math.floor(231 + (76 - 231) * f + 0.5)
    local g = math.floor(76 + (200 - 76) * f + 0.5)
    local b = math.floor(60 + (120 - 60) * f + 0.5)
    return Color3.fromRGB(r, g, b)
end

local function hudTime(sec)
    sec = math.max(0, math.floor(sec or 0))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

--=================================================================
--  СОХРАНЕНИЕ / ЗАГРУЗКА
--=================================================================
local persistQueued = false

function HUD.Persist()
    CFG.__HUD = {
        on = HUD.state.on,
        pos = HUD.state.pos,
        flags = HUD.state.flags,
        scale = HUD.scale,
        lowhp = HUD.lowHp,
        hideInMenu = HUD.hideInMenu,
        alpha = HUD.bgAlpha,
    }
    if persistQueued then return end
    persistQueued = true
    task.delay(0.6, function()
        persistQueued = false
        if type(writefile) ~= "function" then return end
        local ok, json = pcall(function() return Http:JSONEncode(CFG) end)
        if ok and type(json) == "string" then pcall(writefile, HUD_FILE, json) end
    end)
end

local function hudLoad()
    if type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, HUD_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return end
    local ok2, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return end
    local blk = data.__HUD
    if type(blk) ~= "table" then return end
    if type(blk.on) == "table" then
        for id, v in pairs(blk.on) do
            if DEF_BY_ID[id] then HUD.state.on[id] = v and true or false end
        end
    end
    if type(blk.pos) == "table" then
        for id, p in pairs(blk.pos) do
            if DEF_BY_ID[id] and type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
                HUD.state.pos[id] = { x = hpClamp(p.x, 0, 1), y = hpClamp(p.y, 0, 1) }
            end
        end
    end
    if type(blk.flags) == "table" then
        for id, f in pairs(blk.flags) do
            if DEF_BY_ID[id] and type(f) == "table" then
                HUD.state.flags[id] = { bg = f.bg ~= false, blur = f.blur ~= false, theme = f.theme == true }
            end
        end
    end
    if type(blk.scale) == "number" then HUD.scale = hpClamp(blk.scale, 0.7, 1.4) end
    if type(blk.lowhp) == "number" then HUD.lowHp = hpClamp(blk.lowhp, 1, 100) end
    if type(blk.hideInMenu) == "boolean" then HUD.hideInMenu = blk.hideInMenu end
    if type(blk.alpha) == "number" then HUD.bgAlpha = hpClamp(blk.alpha, 0.05, 0.9) end
end

--=================================================================
--  СТИЛЬ / КОРЕНЬ
--=================================================================
local function hudRoot()
    if HUD.gui and HUD.root then return HUD.root end
    HUD.gui = new("ScreenGui", {
        Name = "SpermaHubHUD",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 985,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)
    HUD.root = new("Frame", {
        Name = "Root",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Active = false,
    }, HUD.gui)
    HUD.root.Visible = not (HUD.hideInMenu and HUD.openedMenu)
    return HUD.root
end

local function applyStyle(id)
    local el = HUD.elements[id]
    if not el then return end
    local def, b = el.def, el.btn
    if def.noBg then
        b.BackgroundTransparency = 1
        return
    end
    local fl = HUD.state.flags[id] or {}
    if fl.bg == false then
        b.BackgroundTransparency = 1
    else
        b.BackgroundColor3 = fl.theme and C.accentDim or C.panel
        b.BackgroundTransparency = HUD.bgAlpha - (fl.blur and 0.08 or 0)
    end
end

local function makeRoot(def, w, h)
    local root = hudRoot()
    local b = new("TextButton", {
        Name = "HUD_" .. def.id,
        AnchorPoint = Vector2.new(def.ax, def.ay),
        Position = UDim2.fromScale(HUD.state.pos[def.id].x, HUD.state.pos[def.id].y),
        Size = UDim2.fromOffset(hpScale(w), hpScale(h)),
        BackgroundColor3 = C.panel,
        BackgroundTransparency = HUD.bgAlpha,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
    }, root)
    corner(b, hpScale(5))
    stroke(b, C.accentDim, 0.6, 1)
    return b
end

local function applyPos(id)
    local el = HUD.elements[id]
    if not el then return end
    local p = HUD.state.pos[id]
    el.btn.Position = UDim2.fromScale(p.x, p.y)
end

--=================================================================
--  ДРАГ + КОНТЕКСТНОЕ МЕНЮ ЭЛЕМЕНТА
--=================================================================
local dragState
local elemMenu

local function closeElemMenu()
    if elemMenu then
        pcall(function() elemMenu:Destroy() end)
        elemMenu = nil
    end
end

local function openElemMenu(id, btn)
    closeElemMenu()
    local fl = HUD.state.flags[id]
    if not fl then return end
    local root = hudRoot()
    local mouse = UIS:GetMouseLocation()
    local w, h = hpScale(128), hpScale(78)
    local m = new("Frame", {
        Position = UDim2.fromOffset(mouse.X, mouse.Y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = Color3.fromRGB(12, 17, 25),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 30,
    }, root)
    corner(m, hpScale(4))
    stroke(m, C.accentDim, 0.4, 1)

    local rows = {
        { key = "bg", label = "Фон" },
        { key = "blur", label = "Блюр" },
        { key = "theme", label = "От темы" },
    }
    for i, r in ipairs(rows) do
        local rb = new("TextButton", {
            Position = UDim2.fromOffset(hpScale(4), hpScale(4) + (i - 1) * hpScale(23)),
            Size = UDim2.fromOffset(w - hpScale(8), hpScale(21)),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 31,
        }, m)
        txt(rb, r.label, {
            Position = UDim2.fromOffset(hpScale(6), 0),
            Size = UDim2.new(1, -hpScale(40), 1, 0),
            TextSize = hpScale(11),
            TextColor3 = C.label,
            ZIndex = 32,
        })
        local tr = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -hpScale(6), 0.5, 0),
            Size = UDim2.fromOffset(hpScale(20), hpScale(10)),
            BackgroundColor3 = fl[r.key] and C.accent or C.track,
            BorderSizePixel = 0,
            ZIndex = 32,
        }, rb)
        corner(tr, hpScale(5))
        rb.MouseButton1Click:Connect(function()
            fl[r.key] = not fl[r.key]
            tr.BackgroundColor3 = fl[r.key] and C.accent or C.track
            applyStyle(id)
            HUD.Persist()
        end)
    end
    elemMenu = m
end

local function bindDrag(btn, id)
    btn.InputBegan:Connect(function(input)
        if not input then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local vp = HUD.viewport or Vector2.new(1280, 720)
            local m = UIS:GetMouseLocation()
            local p = HUD.state.pos[id]
            dragState = { id = id, sx = m.X, sy = m.Y, bx = p.x, by = p.y, vp = vp, moved = false }
            closeElemMenu()
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            openElemMenu(id, btn)
        end
    end)
end

do
    local conn = UIS.InputChanged:Connect(function(input)
        if not dragState then return end
        if input and input.UserInputType and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local m = UIS:GetMouseLocation()
        local vp = dragState.vp
        local dx = (m.X - dragState.sx) / math.max(1, vp.X)
        local dy = (m.Y - dragState.sy) / math.max(1, vp.Y)
        local p = HUD.state.pos[dragState.id]
        p.x = hpClamp(dragState.bx + dx, 0, 1)
        p.y = hpClamp(dragState.by + dy, 0, 1)
        applyPos(dragState.id)
        dragState.moved = true
    end)
    local conn2 = UIS.InputEnded:Connect(function(input)
        if dragState and input and input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragState.moved then HUD.Persist() end
            dragState = nil
        end
    end)
    local conn3 = UIS.InputBegan:Connect(function(input)
        if not input then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            closeElemMenu()
        end
    end)
    table.insert(HUD.conns, conn)
    table.insert(HUD.conns, conn2)
    table.insert(HUD.conns, conn3)
end

--=================================================================
--  ДАННЫЕ
--=================================================================
local function hudPing()
    local now = os.clock()
    if HUD.pingAt and now - HUD.pingAt < 0.5 then return HUD.ping or 0 end
    HUD.pingAt = now
    local ok, v = pcall(function()
        local stats = game:GetService("Stats")
        return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(v) == "number" then
        HUD.ping = v
    end
    return HUD.ping or 0
end

local function localHumanoid()
    local ch = LP.Character
    if not ch then return nil, nil end
    return ch:FindFirstChildOfClass("Humanoid"), ch
end

local function targetAlive(plr)
    if not plr or not plr.Parent then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return ch:FindFirstChild("HumanoidRootPart") ~= nil
end

local function hudTarget()
    if HUD.target and targetAlive(HUD.target) then return HUD.target end
    local now = os.clock()
    if FZ.aim.target and FZ.aim.targetAt and now - FZ.aim.targetAt < 1.0 and targetAlive(FZ.aim.target) then
        return FZ.aim.target
    end
    if FZ.silent.target and FZ.silent.targetAt and now - FZ.silent.targetAt < 1.0 and targetAlive(FZ.silent.target) then
        return FZ.silent.target
    end
    return nil
end

local function scanMedia()
    local found = nil
    pcall(function()
        local svc = game:GetService("SoundService")
        for _, s in ipairs(svc:GetDescendants()) do
            local ok, playing = pcall(function() return s.Playing end)
            local ok2, len = pcall(function() return s.TimeLength end)
            if s:IsA("Sound") and ok and playing and ok2 and type(len) == "number" and len > 0 then
                found = s
                break
            end
        end
    end)
    if not found then
        local ch = LP.Character
        if ch then
            pcall(function()
                for _, s in ipairs(ch:GetDescendants()) do
                    local ok, playing = pcall(function() return s.Playing end)
                    if s:IsA("Sound") and ok and playing then
                        found = s
                        break
                    end
                end
            end)
        end
    end
    HUD._media = found
end

local function refreshStaff()
    local out = {}
    local creatorType = nil
    pcall(function() creatorType = game.CreatorType end)
    for _, plr in ipairs(Players:GetPlayers()) do
        local rank = nil
        if creatorType == Enum.CreatorType.User and plr.UserId == game.CreatorId then
            rank = "OWNER"
        elseif creatorType == Enum.CreatorType.Group then
            local ok, r = pcall(function() return plr:GetRankInGroup(game.CreatorId) end)
            if ok and type(r) == "number" and r >= 200 then
                rank = (r >= 255) and "OWNER" or "MOD"
            end
        end
        local custom = HUD.staffIds[plr.UserId]
        if custom then rank = custom end
        if rank then table.insert(out, { name = plr.Name, rank = rank }) end
    end
    HUD._staff = out
end

local function startScans()
    task.spawn(function()
        while HUD.alive do
            pcall(scanMedia)
            pcall(refreshStaff)
            task.wait(4)
        end
    end)
end

--=================================================================
--  ЭЛЕМЕНТЫ
--=================================================================
local builders = {}

-- --- ватермарка ------------------------------------------------
builders.watermark = function(def)
    local b = makeRoot(def, 0, 28)
    b.AutomaticSize = Enum.AutomaticSize.X
    b.BackgroundTransparency = 0.18
    new("UIPadding", {
        PaddingLeft = UDim.new(0, hpScale(9)),
        PaddingRight = UDim.new(0, hpScale(8)),
    }, b)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, hpScale(7)),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, b)

    local bar = new("Frame", {
        Size = UDim2.fromOffset(hpScale(3), hpScale(13)),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    }, b)
    corner(bar, hpScale(1))

    txt(b, "SPERMAHUB", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = F.black,
        TextSize = hpScale(12),
        TextColor3 = C.text,
        LayoutOrder = 2,
    })

    local sep = new("Frame", {
        Size = UDim2.fromOffset(hpScale(1), hpScale(12)),
        BackgroundColor3 = C.line,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        LayoutOrder = 3,
    }, b)

    local stats = txt(b, "", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize = hpScale(11),
        TextColor3 = C.dim,
        LayoutOrder = 4,
    })

    local gear = new("TextButton", {
        Size = UDim2.fromOffset(hpScale(14), hpScale(14)),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 5,
    }, b)
    local gearIcon = iconSlot(gear, "gear", {
        size = UDim2.fromScale(1, 1),
        textSize = hpScale(11),
        font = F.bold,
        color = C.dim,
    })

    local spin = Tween:Create(gearIcon.holder or gear, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
        Rotation = 360,
    })
    pcall(function() spin:Play() end)

    gear.MouseEnter:Connect(function() iconTint(gearIcon, C.accent) end)
    gear.MouseLeave:Connect(function() iconTint(gearIcon, C.dim) end)
    gear.MouseButton1Click:Connect(function()
        local ui = getgenv and getgenv().SpermaHubUI
        if ui and ui.Toggle then pcall(ui.Toggle, true) end
    end)

    local _ = sep
    return b, function()
        stats.Text = string.format("%s  %d FPS  %d ms  %s",
            tostring(LP.Name),
            math.floor(HUD.fps + 0.5),
            math.floor(hudPing() + 0.5),
            os.date("%H:%M"))
    end
end

-- --- arraylist -------------------------------------------------
local AL_MODULES = {
    { "aim", "Aimbot" },
    { "assist", "Aim Assist" },
    { "silent", "Silent Aim" },
    { "hitbox", "Hitbox" },
    { "esp", "ESP" },
    { "fly", "Fly" },
    { "noclip", "Noclip" },
    { "airstuck", "Air Stuck" },
    { "ghost", "Ghost Stand" },
    { "scaffold", "Scaffold" },
    { "clickTp", "Click TP" },
    { "walk", "Speed" },
}

builders.arraylist = function(def)
    local b = makeRoot(def, 0, 0)
    b.AutomaticSize = Enum.AutomaticSize.XY
    new("UIListLayout", {
        Padding = UDim.new(0, hpScale(2)),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, b)

    local rows = {}
    local lastKey = ""

    local function rebuild(names)
        for _, r in ipairs(rows) do pcall(function() r.frame:Destroy() end) end
        rows = {}
        for i, name in ipairs(names) do
            local w = hpScale(math.max(64, math.floor(#name * 6.6 + 28)))
            local row = new("Frame", {
                Size = UDim2.fromOffset(w, hpScale(16)),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = i,
            }, b)
            local fill = new("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = C.accent,
                BackgroundTransparency = HUD.bgAlpha + 0.16,
                BorderSizePixel = 0,
            }, row)
            corner(fill, hpScale(2))
            new("UIGradient", { Color = ColorSequence.new(C.accent, C.panel), Rotation = 0 }, fill)
            new("Frame", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.fromOffset(hpScale(2), hpScale(16)),
                BackgroundColor3 = C.accent,
                BorderSizePixel = 0,
            }, row)
            txt(row, name, {
                Size = UDim2.new(1, -hpScale(8), 1, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
                Font = F.bold,
                TextSize = hpScale(12),
                TextColor3 = C.text,
            })
            Tween:Create(fill, TweenInfo.new(0.18), { BackgroundTransparency = HUD.bgAlpha + 0.16 }):Play()
            table.insert(rows, { frame = row, name = name })
        end
    end

    return b, function()
        local names = {}
        for _, m in ipairs(AL_MODULES) do
            local f = FZ[m[1]]
            if f and f.on then table.insert(names, m[2]) end
        end
        table.sort(names, function(x, y) return #x > #y end)
        local key = table.concat(names, "\n")
        if key ~= lastKey then
            lastKey = key
            rebuild(names)
        end
        b.Visible = #names > 0
    end
end

-- --- активный таргет -------------------------------------------
builders.target = function(def)
    local b = makeRoot(def, 202, 64)
    b.Visible = false
    new("Frame", {
        Size = UDim2.fromOffset(hpScale(2), hpScale(64)),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, b)
    local avatar = new("ImageLabel", {
        Position = UDim2.fromOffset(hpScale(10), hpScale(11)),
        Size = UDim2.fromOffset(hpScale(42), hpScale(42)),
        BackgroundColor3 = C.input,
        BorderSizePixel = 0,
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
    }, b)
    corner(avatar, hpScale(4))

    local nameLbl = txt(b, "", {
        Position = UDim2.fromOffset(hpScale(60), hpScale(9)),
        Size = UDim2.fromOffset(hpScale(132), hpScale(16)),
        Font = F.bold,
        TextSize = hpScale(13),
        TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local hpBg = new("Frame", {
        Position = UDim2.fromOffset(hpScale(60), hpScale(31)),
        Size = UDim2.fromOffset(hpScale(132), hpScale(4)),
        BackgroundColor3 = C.track,
        BorderSizePixel = 0,
    }, b)
    corner(hpBg, hpScale(2))
    local hpFill = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(76, 200, 120),
        BorderSizePixel = 0,
    }, hpBg)
    corner(hpFill, hpScale(2))
    local hpTxt = txt(b, "", {
        Position = UDim2.fromOffset(hpScale(60), hpScale(39)),
        Size = UDim2.fromOffset(hpScale(70), hpScale(14)),
        TextSize = hpScale(11),
        TextColor3 = C.dim,
    })
    local distLbl = txt(b, "", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -hpScale(10), 0, hpScale(39)),
        Size = UDim2.fromOffset(hpScale(60), hpScale(14)),
        TextSize = hpScale(11),
        TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local lastId = nil
    return b, function()
        local plr = hudTarget()
        if not plr then
            b.Visible = false
            lastId = nil
            return
        end
        b.Visible = true
        local ch = plr.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then
            b.Visible = false
            return
        end
        nameLbl.Text = plr.Name
        if lastId ~= plr.UserId then
            lastId = plr.UserId
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(plr.UserId) .. "&w=150&h=150"
        end
        local frac = 0
        if hum.MaxHealth > 0 then frac = hpClamp(hum.Health / hum.MaxHealth, 0, 1) end
        hpFill.Size = UDim2.fromScale(frac, 1)
        hpFill.BackgroundColor3 = hpColor(frac)
        hpTxt.Text = string.format("%d HP", math.floor(hum.Health + 0.5))
        local _, myCh = localHumanoid()
        local myRoot = myCh and myCh:FindFirstChild("HumanoidRootPart")
        local hisRoot = ch:FindFirstChild("HumanoidRootPart")
        if myRoot and hisRoot then
            distLbl.Text = string.format("%dm", math.floor((myRoot.Position - hisRoot.Position).Magnitude + 0.5))
        else
            distLbl.Text = ""
        end
    end
end

-- --- привязанные модули ----------------------------------------
builders.keybinds = function(def)
    local b = makeRoot(def, 150, 0)
    b.AutomaticSize = Enum.AutomaticSize.Y
    new("UIPadding", { PaddingLeft = UDim.new(0, hpScale(8)), PaddingRight = UDim.new(0, hpScale(8)), PaddingTop = UDim.new(0, hpScale(6)), PaddingBottom = UDim.new(0, hpScale(6)) }, b)
    new("UIListLayout", { Padding = UDim.new(0, hpScale(3)), SortOrder = Enum.SortOrder.LayoutOrder }, b)

    local rows = {}
    local lastKey = ""
    local function rebuild(list)
        for _, r in ipairs(rows) do pcall(function() r.frame:Destroy() end) end
        rows = {}
        for i, kb in ipairs(list) do
            local row = new("Frame", {
                Size = UDim2.new(1, 0, 0, hpScale(16)),
                BackgroundTransparency = 1,
                LayoutOrder = i,
            }, b)
            local chip = new("Frame", {
                Size = UDim2.fromOffset(hpScale(42), hpScale(14)),
                BackgroundColor3 = C.accentDim,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
            }, row)
            corner(chip, hpScale(3))
            txt(chip, kb.key, {
                Size = UDim2.fromScale(1, 1),
                Font = F.bold,
                TextSize = hpScale(10),
                TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Center,
            })
            txt(row, kb.label, {
                Position = UDim2.fromOffset(hpScale(50), 0),
                Size = UDim2.new(1, -hpScale(50), 1, 0),
                TextSize = hpScale(12),
                TextColor3 = C.label,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            table.insert(rows, { frame = row })
        end
    end

    return b, function()
        local key = ""
        for _, kb in ipairs(HUD.keybinds) do key = key .. kb.key .. "=" .. kb.label .. ";" end
        if key ~= lastKey then
            lastKey = key
            rebuild(HUD.keybinds)
        end
        b.Visible = #HUD.keybinds > 0
    end
end

-- --- активные модераторы ---------------------------------------
builders.staff = function(def)
    local b = makeRoot(def, 170, 0)
    b.AutomaticSize = Enum.AutomaticSize.Y
    new("UIPadding", { PaddingLeft = UDim.new(0, hpScale(8)), PaddingRight = UDim.new(0, hpScale(8)), PaddingTop = UDim.new(0, hpScale(5)), PaddingBottom = UDim.new(0, hpScale(6)) }, b)
    new("UIListLayout", { Padding = UDim.new(0, hpScale(3)), SortOrder = Enum.SortOrder.LayoutOrder }, b)

    local rows = {}
    local lastKey = ""
    local function rebuild(list)
        for _, r in ipairs(rows) do pcall(function() r.frame:Destroy() end) end
        rows = {}
        local head = txt(b, "STAFF", {
            Size = UDim2.new(1, 0, 0, hpScale(14)),
            Font = F.bold,
            TextSize = hpScale(9),
            TextColor3 = C.faint,
            LayoutOrder = 1,
        })
        local _ = head
        table.insert(rows, { frame = head })
        for i, s in ipairs(list) do
            local row = new("Frame", {
                Size = UDim2.new(1, 0, 0, hpScale(15)),
                BackgroundTransparency = 1,
                LayoutOrder = i + 1,
            }, b)
            local dot = new("Frame", {
                Position = UDim2.fromOffset(0, hpScale(5)),
                Size = UDim2.fromOffset(hpScale(5), hpScale(5)),
                BackgroundColor3 = Color3.fromRGB(238, 92, 92),
                BorderSizePixel = 0,
            }, row)
            corner(dot, hpScale(3))
            txt(row, s.name, {
                Position = UDim2.fromOffset(hpScale(11), 0),
                Size = UDim2.new(1, -hpScale(52), 1, 0),
                TextSize = hpScale(12),
                TextColor3 = C.label,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            txt(row, s.rank, {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.fromOffset(hpScale(44), hpScale(15)),
                TextSize = hpScale(9),
                TextColor3 = C.faint,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
            table.insert(rows, { frame = row })
        end
    end

    return b, function()
        local list = HUD._staff or {}
        local key = ""
        for _, s in ipairs(list) do key = key .. s.name .. s.rank .. ";" end
        if key ~= lastKey then
            lastKey = key
            rebuild(list)
        end
        b.Visible = #list > 0
    end
end

-- --- бафы ------------------------------------------------------
builders.potions = function(def)
    local b = makeRoot(def, 158, 0)
    b.AutomaticSize = Enum.AutomaticSize.Y
    new("UIPadding", { PaddingLeft = UDim.new(0, hpScale(8)), PaddingRight = UDim.new(0, hpScale(8)), PaddingTop = UDim.new(0, hpScale(5)), PaddingBottom = UDim.new(0, hpScale(6)) }, b)
    new("UIListLayout", { Padding = UDim.new(0, hpScale(3)), SortOrder = Enum.SortOrder.LayoutOrder }, b)

    local rows = {}
    local lastKey = ""

    local function collect()
        local out = {}
        if FZ.fly.on then table.insert(out, { name = "Fly", time = nil }) end
        if FZ.noclip.on then table.insert(out, { name = "Noclip", time = nil }) end
        if FZ.airstuck.on then table.insert(out, { name = "Air Stuck", time = nil }) end
        if FZ.ghost.on then table.insert(out, { name = "Ghost Stand", time = nil }) end
        if FZ.aim.on then table.insert(out, { name = "Aimbot", time = nil }) end
        if FZ.silent.on then table.insert(out, { name = "Silent Aim", time = nil }) end
        if FZ.esp.on then table.insert(out, { name = "ESP", time = nil }) end
        if FZ.hitbox.on then table.insert(out, { name = "Hitbox x" .. tostring(FZ.hitbox.size), time = nil }) end
        if FZ.walk.on then table.insert(out, { name = "Speed " .. tostring(math.floor(FZ.walk.speed + 0.5)), time = nil }) end
        local now = os.clock()
        for i = #HUD.buffs, 1, -1 do
            local buff = HUD.buffs[i]
            if buff.until_ and buff.until_ <= now then
                table.remove(HUD.buffs, i)
            else
                table.insert(out, { name = buff.name, time = buff.until_ and (buff.until_ - now) or nil })
            end
        end
        return out
    end

    local function rebuild(list)
        for _, r in ipairs(rows) do pcall(function() r.frame:Destroy() end) end
        rows = {}
        for i, buff in ipairs(list) do
            local row = new("Frame", {
                Size = UDim2.new(1, 0, 0, hpScale(15)),
                BackgroundTransparency = 1,
                LayoutOrder = i,
            }, b)
            local dot = new("Frame", {
                Position = UDim2.fromOffset(0, hpScale(4)),
                Size = UDim2.fromOffset(hpScale(7), hpScale(7)),
                BackgroundColor3 = C.accent,
                BorderSizePixel = 0,
            }, row)
            corner(dot, hpScale(4))
            txt(row, buff.name, {
                Position = UDim2.fromOffset(hpScale(13), 0),
                Size = UDim2.new(1, -hpScale(48), 1, 0),
                TextSize = hpScale(12),
                TextColor3 = C.label,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            if buff.time then
                txt(row, hudTime(buff.time), {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, 0, 0, 0),
                    Size = UDim2.fromOffset(hpScale(38), hpScale(15)),
                    TextSize = hpScale(10),
                    TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Right,
                })
            end
            table.insert(rows, { frame = row })
        end
    end

    return b, function()
        local list = collect()
        local key = ""
        for _, buff in ipairs(list) do key = key .. buff.name .. ";" end
        if key ~= lastKey then
            lastKey = key
            rebuild(list)
        end
        b.Visible = #list > 0
    end
end

-- --- media player ----------------------------------------------
builders.media = function(def)
    local b = makeRoot(def, 200, 48)
    b.Visible = false
    local holder = new("Frame", {
        Name = "HUD_box",
        Position = UDim2.fromOffset(hpScale(8), hpScale(10)),
        Size = UDim2.fromOffset(hpScale(28), hpScale(28)),
        BackgroundColor3 = C.accentDim,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    }, b)
    local eq = {}
    for i = 1, 3 do
        local bar = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, hpScale((i - 2) * 5), 0.84, 0),
            Size = UDim2.fromOffset(hpScale(2), hpScale(8 + i * 3)),
            BackgroundColor3 = C.text,
            BorderSizePixel = 0,
        }, holder)
        eq[i] = bar
    end
    local title = txt(b, "", {
        Position = UDim2.fromOffset(hpScale(44), hpScale(6)),
        Size = UDim2.new(1, -hpScale(52), 0, hpScale(15)),
        Font = F.bold,
        TextSize = hpScale(11),
        TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local sub = txt(b, "", {
        Position = UDim2.fromOffset(hpScale(44), hpScale(21)),
        Size = UDim2.new(1, -hpScale(52), 0, hpScale(13)),
        TextSize = hpScale(9),
        TextColor3 = C.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local barBg = new("Frame", {
        Position = UDim2.fromOffset(hpScale(44), hpScale(37)),
        Size = UDim2.new(1, -hpScale(64), 0, hpScale(3)),
        BackgroundColor3 = C.track,
        BorderSizePixel = 0,
    }, b)
    corner(barBg, hpScale(2))
    local barFill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, barBg)
    corner(barFill, hpScale(2))
    local timeLbl = txt(b, "", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -hpScale(8), 0, hpScale(31)),
        Size = UDim2.fromOffset(hpScale(48), hpScale(12)),
        TextSize = hpScale(9),
        TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local phase = 0
    return b, function(dt)
        local s = HUD._media
        local okPlaying = false
        if s then
            pcall(function() okPlaying = s.Playing end)
        end
        if not s or not okPlaying then
            b.Visible = false
            return
        end
        b.Visible = true
        local ok, name = pcall(function() return s.Name end)
        title.Text = ok and name or "Sound"
        local okId, id = pcall(function() return tostring(s.SoundId) end)
        sub.Text = okId and id:gsub("rbxassetid://", "") or ""
        local okPos, pos = pcall(function() return s.TimePosition end)
        local okLen, len = pcall(function() return s.TimeLength end)
        if type(pos) == "number" and type(len) == "number" and len > 0 then
            barFill.Size = UDim2.fromScale(hpClamp(pos / len, 0, 1), 1)
            timeLbl.Text = hudTime(pos) .. "/" .. hudTime(len)
        else
            timeLbl.Text = ""
        end
        phase = phase + (dt or 0.05)
        for i = 1, 3 do
            local h = 6 + math.abs(math.sin(phase * 4 + i * 1.7)) * 12
            eq[i].Size = UDim2.fromOffset(hpScale(2), hpScale(h))
        end
    end
end

-- --- тики / пинг -----------------------------------------------
builders.ticks = function(def)
    local b = makeRoot(def, 66, 18)
    local lbl = txt(b, "TICK", {
        Size = UDim2.fromScale(1, 1),
        Font = F.bold,
        TextSize = hpScale(11),
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    return b, function()
        local tps = HUD.fps
        lbl.Text = string.format("TICK %.2f", math.floor(tps * 100 + 0.5) / 100)
        if tps >= 55 then
            lbl.TextColor3 = Color3.fromRGB(120, 214, 140)
        elseif tps >= 30 then
            lbl.TextColor3 = Color3.fromRGB(232, 200, 96)
        else
            lbl.TextColor3 = Color3.fromRGB(236, 108, 104)
        end
    end
end

builders.ping = function(def)
    local b = makeRoot(def, 70, 18)
    local lbl = txt(b, "PING", {
        Size = UDim2.fromScale(1, 1),
        Font = F.bold,
        TextSize = hpScale(11),
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    return b, function()
        local ms = hudPing()
        lbl.Text = string.format("PING %d", math.floor(ms + 0.5))
        if ms <= 60 then
            lbl.TextColor3 = Color3.fromRGB(120, 214, 140)
        elseif ms <= 120 then
            lbl.TextColor3 = Color3.fromRGB(232, 200, 96)
        else
            lbl.TextColor3 = Color3.fromRGB(236, 108, 104)
        end
    end
end

-- --- скорость / сейвы ------------------------------------------
builders.speed = function(def)
    local b = makeRoot(def, 76, 18)
    local lbl = txt(b, "", {
        Size = UDim2.fromScale(1, 1),
        Font = F.bold,
        TextSize = hpScale(11),
        TextColor3 = C.accent,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    return b, function()
        local hum = localHumanoid()
        local spd = hum and hum.WalkSpeed or 16
        lbl.Text = string.format("SPD %.1f", spd)
        lbl.TextColor3 = (spd > 16.5) and C.accent or C.dim
    end
end

builders.totems = function(def)
    local b = makeRoot(def, 84, 18)
    local lbl = txt(b, "SAVES 0", {
        Size = UDim2.fromScale(1, 1),
        Font = F.bold,
        TextSize = hpScale(11),
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    return b, function()
        local hum = localHumanoid()
        if not hum or hum.MaxHealth <= 0 then
            b.Visible = false
            return
        end
        b.Visible = true
        local frac = hum.Health / hum.MaxHealth
        if frac <= 0.25 then
            HUD.lowFlag = true
        elseif HUD.lowFlag and frac >= 0.6 then
            HUD.lowFlag = false
            HUD.saves = HUD.saves + 1
        end
        lbl.Text = string.format("SAVES %d", HUD.saves)
        lbl.TextColor3 = HUD.lowFlag and Color3.fromRGB(236, 108, 104) or C.text
    end
end

-- --- кулдауны --------------------------------------------------
builders.cooldowns = function(def)
    local b = makeRoot(def, 176, 0)
    b.AutomaticSize = Enum.AutomaticSize.Y
    new("UIPadding", { PaddingLeft = UDim.new(0, hpScale(8)), PaddingRight = UDim.new(0, hpScale(8)), PaddingTop = UDim.new(0, hpScale(5)), PaddingBottom = UDim.new(0, hpScale(6)) }, b)
    new("UIListLayout", { Padding = UDim.new(0, hpScale(4)), SortOrder = Enum.SortOrder.LayoutOrder }, b)

    local rows = {}
    local lastKey = ""

    local function rebuild(list)
        for _, r in ipairs(rows) do pcall(function() r.frame:Destroy() end) end
        rows = {}
        for i, cd in ipairs(list) do
            local row = new("Frame", {
                Size = UDim2.new(1, 0, 0, hpScale(19)),
                BackgroundTransparency = 1,
                LayoutOrder = i,
            }, b)
            txt(row, cd.name, {
                Size = UDim2.new(1, -hpScale(36), 0, hpScale(13)),
                TextSize = hpScale(11),
                TextColor3 = C.label,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local left = txt(row, "", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.fromOffset(hpScale(34), hpScale(13)),
                TextSize = hpScale(10),
                TextColor3 = C.dim,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
            local barBg = new("Frame", {
                Position = UDim2.fromOffset(0, hpScale(14)),
                Size = UDim2.new(1, 0, 0, hpScale(3)),
                BackgroundColor3 = C.track,
                BorderSizePixel = 0,
            }, row)
            corner(barBg, hpScale(2))
            local barFill = new("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = C.accent,
                BorderSizePixel = 0,
            }, barBg)
            corner(barFill, hpScale(2))
            table.insert(rows, { frame = row, name = cd.name, fill = barFill, left = left, total = cd.total, until_ = cd.until_ })
        end
    end

    return b, function()
        local now = os.clock()
        local list = {}
        for i = #HUD.cooldowns, 1, -1 do
            if HUD.cooldowns[i].until_ <= now then table.remove(HUD.cooldowns, i) end
        end
        for _, cd in ipairs(HUD.cooldowns) do
            table.insert(list, cd)
        end
        local key = ""
        for _, cd in ipairs(list) do key = key .. cd.name .. ";" end
        if key ~= lastKey then
            lastKey = key
            rebuild(list)
        end
        b.Visible = #list > 0
        for _, row in ipairs(rows) do
            local left = row.until_ - now
            if left < 0 then left = 0 end
            row.left.Text = string.format("%.1f", left)
            row.fill.Size = UDim2.fromScale(hpClamp(left / math.max(0.01, row.total), 0, 1), 1)
        end
    end
end

-- --- нотификации -----------------------------------------------
builders.notifications = function(def)
    local b = makeRoot(def, 252, 0)
    b.AutomaticSize = Enum.AutomaticSize.Y
    new("UIListLayout", { Padding = UDim.new(0, hpScale(4)), SortOrder = Enum.SortOrder.LayoutOrder }, b)
    HUD._toastHolder = b
    HUD._toastOrder = 0
    return b, function()
        b.Visible = true
    end
end

function HUD.Push(text)
    local holder = HUD._toastHolder
    if not holder or not holder.Parent then return end
    text = tostring(text or "")
    HUD._toastOrder = (HUD._toastOrder or 0) + 1
    local toast = new("Frame", {
        Size = UDim2.new(1, 0, 0, hpScale(30)),
        BackgroundColor3 = Color3.fromRGB(12, 17, 25),
        BackgroundTransparency = HUD.bgAlpha,
        BorderSizePixel = 0,
        LayoutOrder = HUD._toastOrder,
    }, holder)
    corner(toast, hpScale(4))
    stroke(toast, C.accentDim, 0.5, 1)
    new("Frame", {
        Size = UDim2.fromOffset(hpScale(2), hpScale(30)),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, toast)
    txt(toast, "SPERMAHUB", {
        Position = UDim2.fromOffset(hpScale(10), hpScale(3)),
        Size = UDim2.new(1, -hpScale(18), 0, hpScale(11)),
        Font = F.bold,
        TextSize = hpScale(9),
        TextColor3 = C.faint,
    })
    txt(toast, text, {
        Position = UDim2.fromOffset(hpScale(10), hpScale(14)),
        Size = UDim2.new(1, -hpScale(18), 0, hpScale(13)),
        TextSize = hpScale(11),
        TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local count = #holder:GetChildren()
    if count > 12 then
        for _, ch in ipairs(holder:GetChildren()) do
            if ch:IsA("Frame") then pcall(function() ch:Destroy() end) break end
        end
    end
    task.delay(3.2, function()
        if toast and toast.Parent then
            local ti = TweenInfo.new(0.25)
            Tween:Create(toast, ti, { BackgroundTransparency = 1 }):Play()
            task.delay(0.3, function()
                if toast and toast.Parent then pcall(function() toast:Destroy() end) end
            end)
        end
    end)
end

-- --- низкое ХП -------------------------------------------------
builders.lowhp = function(def)
    local root = hudRoot()
    local b = new("Frame", {
        Name = "HUD_lowhp",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(150, 24, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
    }, root)
    local tint = b
    local edges = {}
    local function edge(pos, size, anchor)
        local f = new("Frame", {
            AnchorPoint = anchor or Vector2.new(0, 0),
            Position = pos,
            Size = size,
            BackgroundColor3 = Color3.fromRGB(214, 52, 52),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Active = false,
        }, b)
        table.insert(edges, f)
        return f
    end
    edge(UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, hpScale(3)))
    edge(UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0, hpScale(3)), Vector2.new(0, 1))
    edge(UDim2.fromOffset(0, 0), UDim2.new(0, hpScale(3), 1, 0))
    edge(UDim2.new(1, 0, 0, 0), UDim2.new(0, hpScale(3), 1, 0), Vector2.new(1, 0))

    local phase = 0
    return b, function(dt)
        local hum = localHumanoid()
        local active = false
        if hum and hum.MaxHealth > 0 and hum.Health > 0 then
            active = (hum.Health / hum.MaxHealth) * 100 <= HUD.lowHp
        end
        if not active then
            b.Visible = false
            return
        end
        b.Visible = true
        phase = phase + (dt or 0.05)
        local pulse = 0.5 + 0.5 * math.sin(phase * 6)
        tint.BackgroundTransparency = 0.95 - pulse * 0.03
        for _, f in ipairs(edges) do
            f.BackgroundTransparency = 0.62 - pulse * 0.25
        end
    end
end

--=================================================================
--  TARGET ESP + ARROWS
--=================================================================
--  targetesp  — маркер-ромб над выбранной целью (билборд в мире)
--  arrows     — стрелки на экране, показывают где игроки
--  Оба висят на RenderStepped и отключаются через HUD.SetTargetESP /
--  HUD.SetArrows, состояние живёт в HUD.te / HUD.ar.
--=================================================================
local MARKER_IMAGE = "rbxassetid://114677874909839"
local ARROW_TEXTURES = {
    "rbxassetid://107466177907852",
    "rbxassetid://73377822137093",
}

HUD.te = {
    on = true,
    size = 2.6,
    range = 260,
    color = Color3.fromRGB(255, 255, 255),
    progress = 0,
    value = 0,
    angle = 0,
    speed = 0,
    dir = 1,
    lastCh = nil,
    anchor = nil,
    gui = nil,
    img = nil,
}

HUD.ar = {
    on = false,
    radius = 110,
    size = 26,
    maxDist = 2000,
    mode = 1,
    speed = 3.2,
    color = Color3.fromRGB(255, 255, 255),
    gui = nil,
    list = {},
    prog = {},
    last = {},
}

local function teEnsure()
    local st = HUD.te
    if st.gui and st.gui.Parent and st.anchor and st.anchor.Parent then return true end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local anchor = new("Part", {
        Name = "SpermaHubTargetESP",
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        Transparency = 1,
        Size = Vector3.new(0.1, 0.1, 0.1),
        Parent = cam,
    })
    if not anchor then return false end
    local bb = new("BillboardGui", {
        Name = "SpermaHubTargetMarker",
        Adornee = anchor,
        AlwaysOnTop = true,
        LightInfluence = 0,
        Size = UDim2.fromScale(6, 6),
        Enabled = false,
        Parent = anchor,
    })
    local img = new("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        Image = MARKER_IMAGE,
        ScaleType = Enum.ScaleType.Fit,
        ImageColor3 = st.color,
        ImageTransparency = 1,
        Parent = bb,
    })
    st.anchor, st.gui, st.img = anchor, bb, img
    return true
end

local function teTarget()
    local t = hudTarget()
    if t and targetAlive(t) then return t end
    local ch = LP.Character
    local myRoot = ch and ch:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local best, bestD = nil, HUD.te.range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and targetAlive(plr) then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - myRoot.Position).Magnitude
                if d < bestD then
                    best, bestD = plr, d
                end
            end
        end
    end
    return best
end

local function teStep(dt)
    local st = HUD.te
    if not st.on then
        if st.gui then st.gui.Enabled = false end
        st.progress = 0
        st.value = 0
        st.lastCh = nil
        return
    end
    if not teEnsure() then return end

    local plr = teTarget()
    local has = plr ~= nil
    if plr and plr.Character then st.lastCh = plr.Character end
    local ch = st.lastCh

    local step = dt / 0.35
    st.progress = math.clamp(st.progress + (has and step or -step), 0, 1)
    st.value = 1 - (1 - st.progress) ^ 3

    if not has and st.progress <= 0 then
        st.lastCh = nil
    end
    if not ch or not ch.Parent or st.value <= 0.01 then
        st.gui.Enabled = false
        return
    end

    local ok, cf = pcall(function() return ch:GetBoundingBox() end)
    if not ok or not cf then
        st.gui.Enabled = false
        return
    end

    st.anchor.Position = cf.Position

    local k = dt * 60
    if st.dir > 0 then
        st.speed = st.speed + 0.01 * k
        if st.speed > 2.3 then
            st.speed = 2.3
            st.dir = -1
        end
    else
        st.speed = st.speed - 0.01 * k
        if st.speed < -2.3 then
            st.speed = -2.3
            st.dir = 1
        end
    end
    st.angle = (st.angle + st.speed * k) % 360

    local side = 1.8 * st.value * st.size
    st.gui.Size = UDim2.fromScale(side, side)
    st.gui.Enabled = true
    st.img.ImageTransparency = 1 - st.value
    st.img.Rotation = st.angle
    st.img.ImageColor3 = st.color
end

local function arEnsure()
    local st = HUD.ar
    if st.gui and st.gui.Parent then return st.gui end
    st.gui = new("ScreenGui", {
        Name = "SpermaHubArrows",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 984,
    }, PlayerGui)
    return st.gui
end

local function arClear()
    local st = HUD.ar
    for _, a in pairs(st.list) do
        pcall(function() a:Destroy() end)
    end
    st.list, st.prog, st.last = {}, {}, {}
    if st.gui then
        pcall(function() st.gui:Destroy() end)
        st.gui = nil
    end
end

local function arRoot(plr)
    local ch = plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function arAlive(plr)
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function arStep(dt)
    local st = HUD.ar
    local cam = workspace.CurrentCamera
    if not st.on or not cam then
        if st.gui then arClear() end
        return
    end
    local gui = arEnsure()
    if not gui then return end

    local vp = cam.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local myRoot = arRoot(LP)

    local want = {}
    if myRoot then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local r = arRoot(plr)
                if r and arAlive(plr) then
                    local dist = (r.Position - myRoot.Position).Magnitude
                    if dist <= st.maxDist then want[plr] = true end
                end
            end
        end
    end

    for plr in pairs(want) do
        if not st.list[plr] then
            local arrow = new("ImageLabel", {
                Name = "Arrow_" .. plr.Name,
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Image = ARROW_TEXTURES[st.mode] or ARROW_TEXTURES[1],
                ImageColor3 = Color3.new(1, 1, 1),
                ImageTransparency = 1,
                Size = UDim2.fromOffset(0, 0),
                Visible = false,
            }, gui)
            new("UIGradient", {Name = "Shimmer", Parent = arrow})
            st.list[plr] = arrow
            st.prog[plr] = 0
        end
    end

    local dead = {}
    local now = os.clock()

    for plr, arrow in pairs(st.list) do
        local targetOn = want[plr] and 1 or 0
        local cur = st.prog[plr] or 0
        if cur ~= targetOn then
            local s = dt * st.speed
            if targetOn > cur then
                cur = math.min(cur + s, 1)
            else
                cur = math.max(cur - s, 0)
            end
            st.prog[plr] = cur
        end

        local r = arRoot(plr)
        local localPos
        if r then
            localPos = cam.CFrame:PointToObjectSpace(r.Position)
            st.last[plr] = localPos
        else
            localPos = st.last[plr]
        end

        local tex = ARROW_TEXTURES[st.mode] or ARROW_TEXTURES[1]
        if arrow.Image ~= tex then arrow.Image = tex end

        if cur <= 0.001 and not r then
            arrow.Visible = false
            table.insert(dead, plr)
        elseif not localPos then
            arrow.Visible = false
            if cur <= 0.001 then table.insert(dead, plr) end
        else
            local eased = (targetOn == 1) and (1 - (1 - cur) ^ 3) or cur
            eased = math.max(eased, 0)

            local angle = math.deg(math.atan2(localPos.X, -localPos.Z))
            local rad = math.rad(angle)
            local radLen = st.radius * eased
            local offX = math.sin(rad) * radLen
            local offY = -math.cos(rad) * radLen
            local sz = st.size * eased

            arrow.Size = UDim2.fromOffset(sz, sz)
            arrow.Position = UDim2.fromOffset(cx + offX, cy + offY)
            arrow.Rotation = angle
            arrow.ImageTransparency = 1 - cur
            arrow.Visible = cur > 0.001

            local g = arrow:FindFirstChild("Shimmer")
            if g then
                local h, s, v = Color3.toHSV(st.color)
                local w1 = (math.sin(now * 3.2) + 1) / 2
                local w2 = (math.cos(now * 2.1) + 1) / 2
                local w3 = (math.sin(now * 4.5 + 1.5) + 1) / 2
                local dark = Color3.fromHSV(h, s, math.clamp(v * (0.35 + w1 * 0.3), 0, 1))
                local mid = Color3.fromHSV(h, math.clamp(s * (0.8 + w2 * 0.2), 0, 1), math.clamp(v * (0.65 + w2 * 0.35), 0, 1))
                local light = Color3.fromHSV(h, math.max(0, s * 0.65), math.clamp(v * (1.1 + w3 * 0.4), 0, 1))
                g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, dark),
                    ColorSequenceKeypoint.new(0.5, mid),
                    ColorSequenceKeypoint.new(1, light),
                })
                g.Offset = Vector2.new(math.sin(now * 2.5) * 0.2, math.cos(now * 1.8) * 0.2)
                g.Rotation = (now * 50) % 360
            end
        end
    end

    for _, plr in ipairs(dead) do
        if st.list[plr] then pcall(function() st.list[plr]:Destroy() end) end
        st.list[plr] = nil
        st.prog[plr] = nil
        st.last[plr] = nil
    end
end

HUD.fxConn = RunService.RenderStepped:Connect(function(dt)
    pcall(teStep, dt or 0)
    pcall(arStep, dt or 0)
end)

function HUD.SetTargetESP(on)
    HUD.te.on = on and true or false
    if not HUD.te.on and HUD.te.gui then HUD.te.gui.Enabled = false end
end

function HUD.GetTargetESP()
    return HUD.te.on
end

function HUD.SetTargetESPSize(v)
    HUD.te.size = hpClamp(tonumber(v) or 2.6, 0.5, 10)
end

function HUD.GetTargetESPSize()
    return HUD.te.size
end

function HUD.SetArrows(on)
    HUD.ar.on = on and true or false
    if not HUD.ar.on then arClear() end
end

function HUD.GetArrows()
    return HUD.ar.on
end

function HUD.SetArrowRadius(v)
    HUD.ar.radius = hpClamp(tonumber(v) or 110, 20, 600)
end

function HUD.GetArrowRadius()
    return HUD.ar.radius
end

function HUD.SetArrowSize(v)
    HUD.ar.size = hpClamp(tonumber(v) or 26, 4, 96)
end

function HUD.GetArrowSize()
    return HUD.ar.size
end

function HUD.SetArrowDist(v)
    HUD.ar.maxDist = hpClamp(tonumber(v) or 2000, 50, 10000)
end

function HUD.GetArrowDist()
    return HUD.ar.maxDist
end

function HUD.SetArrowMode(v)
    v = math.floor(tonumber(v) or 1)
    if v < 1 or v > #ARROW_TEXTURES then v = 1 end
    HUD.ar.mode = v
end

function HUD.GetArrowMode()
    return HUD.ar.mode
end

function HUD.DestroyFX()
    if HUD.fxConn then
        pcall(function() HUD.fxConn:Disconnect() end)
        HUD.fxConn = nil
    end
    if HUD.te.gui then
        pcall(function() HUD.te.gui:Destroy() end)
        HUD.te.gui = nil
    end
    if HUD.te.anchor then
        pcall(function() HUD.te.anchor:Destroy() end)
        HUD.te.anchor = nil
    end
    HUD.te.img = nil
    arClear()
end

--=================================================================
--  СБОРКА / РАЗБОРКА
--=================================================================
local applyStyleAll
local bindGlobalHud

function HUD.BuildOne(def)
    if HUD.elements[def.id] then return end
    local builder = builders[def.id]
    if not builder then return end
    local ok, b, update = pcall(builder, def)
    if not ok or not b then
        warn("[SpermaHubHUD] build '" .. def.id .. "': " .. tostring(b))
        return
    end
    HUD.elements[def.id] = { def = def, btn = b, update = update }
    if def.id ~= "lowhp" then bindDrag(b, def.id) end
    applyStyle(def.id)
end

function HUD.DestroyElement(id)
    local el = HUD.elements[id]
    if not el then return end
    HUD.elements[id] = nil
    pcall(function() el.btn:Destroy() end)
    if id == "notifications" then HUD._toastHolder = nil end
end

function HUD.Build()
    hudRoot()
    HUD.viewport = nil
    pcall(function() HUD.viewport = workspace.CurrentCamera.ViewportSize end)
    for _, def in ipairs(HUD_DEFS) do
        if HUD.state.on[def.id] then
            HUD.BuildOne(def)
        end
    end
    applyStyleAll()
end

function HUD.SetEnabled(id, on)
    if not DEF_BY_ID[id] then return end
    HUD.state.on[id] = on and true or false
    if on then
        HUD.BuildOne(DEF_BY_ID[id])
    else
        HUD.DestroyElement(id)
    end
    HUD.Persist()
end

function HUD.IsEnabled(id)
    return HUD.state.on[id] == true
end

function HUD.List()
    return HUD_DEFS
end

applyStyleAll = function()
    for id in pairs(HUD.elements) do
        applyStyle(id)
    end
end

function HUD.SetScale(v)
    v = hpClamp(tonumber(v) or 1, 0.7, 1.4)
    if math.abs(v - HUD.scale) < 0.001 then return end
    HUD.scale = v
    HUD.Rebuild()
    HUD.Persist()
end

function HUD.GetScale()
    return HUD.scale
end

function HUD.SetLowHp(v)
    HUD.lowHp = hpClamp(tonumber(v) or 30, 1, 100)
    HUD.Persist()
end

function HUD.GetLowHp()
    return HUD.lowHp
end

function HUD.SetBgAlpha(v)
    HUD.bgAlpha = hpClamp(tonumber(v) or 0.3, 0.05, 0.9)
    applyStyleAll()
    HUD.Persist()
end

function HUD.GetBgAlpha()
    return HUD.bgAlpha
end

function HUD.SetHideInMenu(v)
    HUD.hideInMenu = v and true or false
    if HUD.root then
        HUD.root.Visible = not (HUD.hideInMenu and HUD.openedMenu)
    end
    HUD.Persist()
end

function HUD.GetHideInMenu()
    return HUD.hideInMenu
end

function HUD.SetMenuOpen(state)
    HUD.openedMenu = state and true or false
    if HUD.root then
        HUD.root.Visible = not (HUD.hideInMenu and HUD.openedMenu)
    end
end

function HUD.ResetPositions()
    for _, d in ipairs(HUD_DEFS) do
        HUD.state.pos[d.id] = { x = d.x, y = d.y }
        applyPos(d.id)
    end
    HUD.Persist()
end

function HUD.AddBuff(name, sec)
    table.insert(HUD.buffs, { name = tostring(name), until_ = os.clock() + (tonumber(sec) or 10) })
end

function HUD.AddCooldown(name, sec)
    table.insert(HUD.cooldowns, {
        name = tostring(name),
        total = math.max(0.1, tonumber(sec) or 1),
        until_ = os.clock() + math.max(0.1, tonumber(sec) or 1),
    })
end

function HUD.AddKeybind(key, label)
    table.insert(HUD.keybinds, 1, { key = tostring(key), label = tostring(label) })
end

function HUD.SetStaff(userId, rank)
    HUD.staffIds[userId] = rank or "MOD"
end

function HUD.SetTarget(plr)
    HUD.target = plr
end

function HUD.Tick(dt)
    for id, el in pairs(HUD.elements) do
        if el.update then
            local ok, err = pcall(el.update, dt)
            if not ok then
                el.err = err
            end
        end
    end
end

function HUD.DestroyVisual()
    for _, c in ipairs(HUD.conns) do pcall(function() c:Disconnect() end) end
    HUD.conns = {}
    closeElemMenu()
    dragState = nil
    for id in pairs(HUD.elements) do HUD.elements[id] = nil end
    HUD._toastHolder = nil
    if HUD.gui then pcall(function() HUD.gui:Destroy() end) end
    HUD.gui = nil
    HUD.root = nil
end

function HUD.Rebuild()
    HUD.DestroyVisual()
    HUD.Build()
    bindGlobalHud()
end

function HUD.Destroy()
    HUD.alive = false
    if HUD.DestroyFX then HUD.DestroyFX() end
    HUD.DestroyVisual()
    if HUD.renderConn then
        pcall(function() HUD.renderConn:Disconnect() end)
        HUD.renderConn = nil
    end
    if getgenv and getgenv().SpermaHubHUD == HUD then
        getgenv().SpermaHubHUD = nil
    end
end

--=================================================================
--  ГЛОБАЛЬНЫЕ КОННЕКТЫ (ресайз и т.п.)
--=================================================================
bindGlobalHud = function()
    local cam = workspace.CurrentCamera
    if cam and cam.GetPropertyChangedSignal then
        local c = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            HUD.viewport = cam.ViewportSize
        end)
        table.insert(HUD.conns, c)
    end
end

--=================================================================
--  СТАРТ
--=================================================================
hudLoad()

HUD.viewport = nil
pcall(function() HUD.viewport = workspace.CurrentCamera.ViewportSize end)
HUD.Build()
bindGlobalHud()

do
    local acc = 0
    local sample = 0
    local frames = 0
    HUD.renderConn = RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        sample = sample + (dt or 0)
        if sample >= 0.5 then
            HUD.fps = frames / sample
            frames = 0
            sample = 0
        end
        acc = acc + (dt or 0)
        if acc < 0.05 then return end
        local step = acc
        acc = 0
        HUD.Tick(step)
    end)
end

startScans()

getgenv().SpermaHubHUD = HUD
HUD.viewport = HUD.viewport or Vector2.new(1280, 720)

--=================================================================
--  СТРАНИЦА НАСТРОЕК HUD
--=================================================================
local function buildInterface(p)
    local hud = p:card("HUD")
    hud:dropdown("Стиль HUD", { "Quick" }, "Quick", false)
    hud:slider("Размер HUD", 70, 140, math.floor(HUD.GetScale() * 100 + 0.5), 5, function(v)
        HUD.SetScale(v / 100)
    end)
    hud:slider("Прозрачность фона", 5, 90, math.floor(HUD.GetBgAlpha() * 100 + 0.5), 1, function(v)
        HUD.SetBgAlpha(v / 100)
    end)
    hud:slider("Порог ХП", 1, 100, math.floor(HUD.GetLowHp() + 0.5), 1, function(v)
        HUD.SetLowHp(v)
    end)
    hud:toggle("Скрывать в меню", HUD.GetHideInMenu(), false, function(on)
        HUD.SetHideInMenu(on)
    end)
    hud:button("Сбросить позиции", function()
        HUD.ResetPositions()
        notify("HUD: позиции сброшены")
    end)
    hud:text("Правый клик по элементу — фон / блюр / от темы. Тяни мышкой, чтобы двигать.")

    local elems = p:card("Элементы", "right")
    for _, d in ipairs(HUD.List()) do
        elems:toggle(d.label, HUD.IsEnabled(d.id), false, function(on)
            HUD.SetEnabled(d.id, on)
        end)
    end
end

--=================================================================
--  КОНТЕНТ СТРАНИЦ (демо по референсу)
--=================================================================
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
FEAT.aimParts = { "Head", "Torso", "Nearest" }

local function buildRagebot(p)
    local aim = p:card("Aimbot")
    aim:toggle("Enabled", false, true, function(on) FEAT.setAimbot(on) end)
    aim:dropdown("Target Part", FEAT.aimParts, FZ.aim.part, false, function(v) FZ.aim.part = v end)
    aim:slider("FOV", 20, 600, FZ.aim.fov, 1, function(v) FZ.aim.fov = v end)
    aim:slider("Smooth", 0.05, 1, FZ.aim.smooth, 0.05, function(v) FZ.aim.smooth = v end)
    aim:slider("Humanize", 0, 1, FZ.aim.humanize, 0.05, function(v) FZ.aim.humanize = v end)
    aim:slider("Max Dist", 50, 2000, FZ.aim.maxDist, 50, function(v) FZ.aim.maxDist = v end)
    aim:toggle("Visible Only", FZ.aim.visibleOnly, false, function(on)
        FZ.aim.visibleOnly = on and true or false
        FZ.aim.visCache = nil
    end)
    aim:toggle("Ignore Team", FZ.aim.ignoreTeam, false, function(on)
        FZ.aim.ignoreTeam = on and true or false
    end)
    aim:toggle("Ignore Friends", FZ.aim.ignoreFriends, false, function(on)
        FZ.aim.ignoreFriends = on and true or false
        FEAT.aim.friendCache = {}
    end)
    aim:text("Smooth — доля шага за кадр (0.05 = очень плавно, 1 = мгновенно), Humanize добавляет живой шум.")

    local silent = p:card("Silent Aim", "right")
    silent:toggle("Enabled", false, true, function(on) setSilentAim(on) end)
    silent:slider("FOV", 20, 600, 150, 1, function(v) FZ.silent.fov = v end)
    silent:text("Нужны hookfunction, getrawmetatable, setreadonly, newcclosure — без них включение отменится.")

    local hit = p:card("Hitbox")
    hit:toggle("Enabled", false, true, function(on) setHitbox(on) end)
    hit:slider("Size", 1, 20, 5, 1, function(v) FZ.hitbox.size = v end)
end

local function buildLegitbot(p)
    local aa = p:card("Aim Assist")
    aa:toggle("Enabled", false, true, function(on) FEAT.setAssist(on) end)
    aa:dropdown("Target Part", FEAT.aimParts, FZ.assist.part, false, function(v) FZ.assist.part = v end)
    aa:slider("FOV", 20, 400, FZ.assist.fov, 5, function(v) FZ.assist.fov = v end)
    aa:slider("Strength", 0.05, 1, FZ.assist.strength, 0.05, function(v) FZ.assist.strength = v end)
    aa:slider("Smooth", 0.05, 1, FZ.assist.smooth, 0.05, function(v) FZ.assist.smooth = v end)
    aa:slider("Humanize", 0, 1, FZ.assist.humanize, 0.05, function(v) FZ.assist.humanize = v end)
    aa:toggle("Only When Firing", FZ.assist.firingOnly, false, function(on)
        FZ.assist.firingOnly = on and true or false
    end)
    aa:text("Мягкая подтяжка прицела: Strength — сколько от нужного поворота за кадр. Aimbot и Assist вместе не работают, включение одного гасит другое.")

    local filt = p:card("Target", "right")
    filt:slider("Max Dist", 50, 2000, FZ.assist.maxDist, 50, function(v) FZ.assist.maxDist = v end)
    filt:toggle("Visible Only", FZ.assist.visibleOnly, false, function(on)
        FZ.assist.visibleOnly = on and true or false
        FZ.assist.visCache = nil
    end)
    filt:toggle("Ignore Team", FZ.assist.ignoreTeam, false, function(on)
        FZ.assist.ignoreTeam = on and true or false
    end)
    filt:toggle("Ignore Friends", FZ.assist.ignoreFriends, false, function(on)
        FZ.assist.ignoreFriends = on and true or false
        FEAT.aim.friendCache = {}
    end)
    filt:text("Only When Firing — тянуть только с зажатой ЛКМ (как в legit-читах).")
end

local function buildPlayers(p)
    local esp = p:card("ESP")
    esp:toggle("Enabled", false, true, function(on) setESP(on) end)
    esp:toggle("Skeleton", FZ.esp.skel, false, function(on) FZ.esp.skel = on end)
    esp:toggle("Ignore Team", FZ.esp.ignoreTeam, false, function(on)
        FZ.esp.ignoreTeam = on and true or false
    end)
    esp:toggle("Ignore Friends", FZ.esp.ignoreFriends, false, function(on)
        FZ.esp.ignoreFriends = on and true or false
        espFriendCache = {}   -- пересчитать кэш заново
    end)
    esp:slider("Max Dist", 50, 2000, FZ.esp.maxDist, 50, function(v)
        FZ.esp.maxDist = v
    end)
    esp:toggle("Only Visible", FZ.esp.visibleOnly, false, function(on)
        FZ.esp.visibleOnly = on and true or false
    end)
    esp:text("Выше — фильтры: тиммейты/друзья/дистанция/видимость.")

    local draw = p:card("Draw", "right")
    draw:toggle("Box", FZ.esp.box, false, function(on) FZ.esp.box = on and true or false end)
    draw:toggle("Name", FZ.esp.name, false, function(on) FZ.esp.name = on and true or false end)
    draw:toggle("HP", FZ.esp.hp, false, function(on) FZ.esp.hp = on and true or false end)
    draw:toggle("Distance", FZ.esp.dist, false, function(on) FZ.esp.dist = on and true or false end)
    draw:dropdown("Box Color", ESP_COLOR_LIST, FZ.esp.colorBox, false, function(v)
        FZ.esp.colorBox = v
    end)
    draw:dropdown("Skeleton Color", ESP_COLOR_LIST, FZ.esp.colorSkel, false, function(v)
        FZ.esp.colorSkel = v
    end)
    draw:dropdown("Text Color", ESP_COLOR_LIST, FZ.esp.colorText, false, function(v)
        FZ.esp.colorText = v
    end)
    draw:dropdown("Chams Color", ESP_COLOR_LIST, FZ.esp.colorChams, false, function(v)
        FZ.esp.colorChams = v
    end)

    local te = p:card("Target ESP", "right")
    te:toggle("Enabled", HUD.GetTargetESP(), false, function(on) HUD.SetTargetESP(on) end)
    te:slider("Size", 1, 8, HUD.GetTargetESPSize(), 0.1, function(v) HUD.SetTargetESPSize(v) end)
    te:text("Маркер крутится над целью. Если хаба нет — берёт ближайшего в радиусе.")

    local ar = p:card("Arrows")
    ar:toggle("Enabled", HUD.GetArrows(), false, function(on) HUD.SetArrows(on) end)
    ar:slider("Radius", 40, 400, HUD.GetArrowRadius(), 1, function(v) HUD.SetArrowRadius(v) end)
    ar:slider("Size", 8, 64, HUD.GetArrowSize(), 1, function(v) HUD.SetArrowSize(v) end)
    ar:slider("Max Dist", 100, 5000, HUD.GetArrowDist(), 50, function(v) HUD.SetArrowDist(v) end)
    ar:dropdown("Texture", {"1", "2"}, tostring(HUD.GetArrowMode()), false, function(v) HUD.SetArrowMode(tonumber(v) or 1) end)
end

--=================================================================
--  POSITION FINDER  (перенос из WindUI-скрипта, но на нашем гуи)
--=================================================================
local GRAB_POS = nil

local function grabRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function fmtVec(v)
    return string.format("Vector3.new(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

local function copyText(text)
    local fn = setclipboard or toclipboard
    if type(fn) ~= "function" then return false end
    return pcall(fn, text)
end

local function buildMain(p)
    local move = p:card("Movement")
    move:toggle("Fly", false, true, function(on) setFly(on) end)
    move:slider("Fly Speed", 10, 300, 50, 1, function(v) FZ.fly.speed = v end)
    move:toggle("Noclip", false, true, function(on) setNoclip(on) end)
    move:toggle("Air Stuck", false, true, function(on) setAirstuck(on) end)
    move:dropdown("Air Stuck Mode", { "Packet", "Physics" }, FZ.airstuck.mode, false, function(v)
        FZ.airstuck.mode = v
        if FZ.airstuck.on then setAirstuck(true) end  -- перезапуск на новом режиме
    end)
    move:slider("Throttle", 10, 500, FZ.airstuck.throttle, 5, function(v)
        FZ.airstuck.throttle = v
        if FZ.airstuck.on and FZ.airstuck.net then FEAT.net.set(v) end
    end)
    move:slider("Max Hold", 0, 60, FZ.airstuck.maxHold, 1, function(v) FZ.airstuck.maxHold = v end)
    move:toggle("Lock Body", false, false, function(on) FZ.airstuck.lock = on and true or false end)
    move:text("Packet — лаг-свитч: режет исходящий трафик, локально двигаешься, для других стоишь. Max Hold сам отпускает, иначе кик. Physics — старый фриз тела в точке.")
    move:toggle("Ghost Stand", false, true, function(on) setGhostFreeze(on) end)
    move:slider("Ghost Cam Speed", 10, 300, GHOST_CAM.speed, 1, function(v) GHOST_CAM.speed = v end)
    move:text("Для других стоишь на месте, камера летит на WASD/Space/Ctrl. Выключишь — появишься там, куда прилетел.")
    move:toggle("Click TP", false, true, function(on) setClickTp(on) end)
    move:slider("TP Height", 0, 20, 3, 1, function(v) FZ.clickTp.height = v end)

    local scf = p:card("Scaffold", "right")
    scf:toggle("Enabled", false, true, function(on) FEAT.setScaffold(on) end)
    scf:dropdown("Fire", { "Activate", "Click" }, FZ.scaffold.mode, false, function(v) FZ.scaffold.mode = v end)
    scf:slider("Grid", 2, 8, FZ.scaffold.grid, 1, function(v) FZ.scaffold.grid = v end)
    scf:slider("Extend", 0, 5, FZ.scaffold.extend, 1, function(v) FZ.scaffold.extend = v end)
    scf:slider("Delay", 0.05, 0.5, FZ.scaffold.delay, 0.01, function(v) FZ.scaffold.delay = v end)
    scf:toggle("Tower", FZ.scaffold.tower, false, function(on) FZ.scaffold.tower = on and true or false end)
    scf:toggle("SafeWalk", FZ.scaffold.safewalk, false, function(on) FZ.scaffold.safewalk = on and true or false end)
    scf:toggle("Downward", FZ.scaffold.downward, false, function(on) FZ.scaffold.downward = on and true or false end)
    scf:toggle("Cursor", FZ.scaffold.cursor, false, function(on) FZ.scaffold.cursor = on and true or false end)
    scf:text("Авто-бридж: ищет дырку под ногами и ставит блок. Нужен инструмент в руках. Камера смотрит в точку установки, курсор ведём через mousemoverel (если executor умеет). Fire=Click — для игр, которые слушают мышь, а не Tool.Activated.")

    local ws = p:card("Walk Speed", "right")
    ws:toggle("Enabled", false, true, function(on) setWalkSpeed(on) end)
    ws:slider("Speed", 16, 300, 16, 1, function(v)
        FZ.walk.speed = v
        applyWalkSpeed()
    end)

    local kill = p:card("Kill Player", "right")
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then table.insert(names, plr.Name) end
    end
    if #names == 0 then names = { "(никого)" } end
    local targetSel = kill:dropdown("Target", names, names[1], false)

    local killToggle
    killToggle = kill:toggle("Kill", false, false, function(on)
        if not on then return end
        killToggle:set(false, true)
        local name = targetSel and targetSel:get()
        local plr = name and Players:FindFirstChild(name)
        killPlayer(plr)
    end)
    kill:text("Телепорт в цель и 30 ударов текущим инструментом.")

    local loc = p:card("Position", "right")
    local locLbl = loc:text("nothing grabbed yet")
    loc:button("Grab", function()
        local root = grabRoot()
        if not root then
            notify("Grab: нет персонажа")
            return
        end
        GRAB_POS = root.Position
        locLbl:set(fmtVec(GRAB_POS))
        notify("Позиция взята: " .. fmtVec(GRAB_POS))
    end)
    loc:button("Copy", function()
        if not GRAB_POS then
            notify("Copy: сначала Grab")
            return
        end
        if copyText(fmtVec(GRAB_POS)) then
            notify("Скопировано")
        else
            notify("Copy: в executor'е нет setclipboard")
        end
    end)
    loc:button("Teleport", function()
        if not GRAB_POS then
            notify("Teleport: сначала Grab")
            return
        end
        local root = grabRoot()
        if not root then
            notify("Teleport: нет персонажа")
            return
        end
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        noclipTeleport(root, GRAB_POS, 0.25)
        pcall(function() root.CFrame = CFrame.new(GRAB_POS) end)
        notify("Телепорт на точку (noclip 0.25 с)")
    end)
end

--=================================================================
--  КОНФИГИ (сохранение в файлы, несколько штук)
--=================================================================
local CONFIG_DIR = "SpermaHubConfigs"
local configName = "default"

local function fsOk()
    return type(readfile) == "function" and type(writefile) == "function"
end

local function ensureConfigDir()
    if type(isfolder) == "function" and type(makefolder) == "function" then
        local ok, exists = pcall(isfolder, CONFIG_DIR)
        if ok and not exists then pcall(makefolder, CONFIG_DIR) end
    end
end

local function sanitizeName(name)
    name = tostring(name or ""):gsub("[^%w_%-%. ]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "default" end
    return name
end

local function configPath(name)
    return CONFIG_DIR .. "/" .. sanitizeName(name) .. ".json"
end

local function listConfigs()
    local out = {}
    if type(listfiles) ~= "function" then return out end
    local ok, files = pcall(listfiles, CONFIG_DIR)
    if not ok or type(files) ~= "table" then return out end
    for _, f in ipairs(files) do
        local base = tostring(f):match("([^/\\]+)%.json$")
        if base then table.insert(out, base) end
    end
    table.sort(out)
    return out
end

local function saveConfigAs(name)
    if not fsOk() then return false, "нет writefile" end
    name = sanitizeName(name)
    ensureConfigDir()
    local ok, json = pcall(function() return Http:JSONEncode(CFG) end)
    if not ok or type(json) ~= "string" then return false, "JSONEncode failed" end
    local wok, err = pcall(writefile, configPath(name), json)
    if not wok then return false, tostring(err) end
    configName = name
    return true
end

local function loadConfigFrom(name)
    if not fsOk() then return false, "нет readfile" end
    name = sanitizeName(name)
    local path = configPath(name)
    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, path)
        if ok and not exists then return false, "нет файла " .. name end
    end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" or raw == "" then return false, "нет файла " .. name end
    local dok, data = pcall(function() return Http:JSONDecode(raw) end)
    if not dok or type(data) ~= "table" then return false, "битый json" end
    local applied = 0
    for key, value in pairs(data) do
        local ctrl = CONTROLS[key]
        if ctrl then
            pcall(function() ctrl:set(value) end)
            applied = applied + 1
        end
        CFG[key] = value
    end
    configName = name
    return true, applied
end

local function deleteConfig(name)
    if type(delfile) ~= "function" then return false, "нет delfile" end
    local ok = pcall(delfile, configPath(name))
    return ok and true or false
end

local function buildConfigs(p)
    local refresh

    local main = p:card("Config")
    local nameBox = main:input("Name", configName)
    local status = main:text("")

    main:button("Save", function()
        local ok, err = saveConfigAs(nameBox:get())
        if ok then
            notify("Config saved: " .. configName)
            status:set("saved: " .. configName)
        else
            notify("Save: " .. tostring(err))
            status:set("error: " .. tostring(err))
        end
        refresh()
    end)

    main:button("Load", function()
        local ok, res = loadConfigFrom(nameBox:get())
        if ok then
            notify("Config loaded: " .. configName .. " (" .. tostring(res) .. " опций)")
            status:set("loaded: " .. configName .. " (" .. tostring(res) .. ")")
        else
            notify("Load: " .. tostring(res))
            status:set("error: " .. tostring(res))
        end
    end)

    main:button("Delete", function()
        local name = sanitizeName(nameBox:get())
        if deleteConfig(name) then
            notify("Config deleted: " .. name)
            status:set("deleted: " .. name)
        else
            notify("Delete: не вышло (нет файла или delfile)")
            status:set("delete failed: " .. name)
        end
        refresh()
    end)

    main:text("Файлы лежат в workspace/" .. CONFIG_DIR .. ". Shift LS — меню, Save в шапке пишет в текущий конфиг.")

    local saved = p:card("Saved", "right")
    local listLbl = saved:text("")
    saved:button("Refresh", function() refresh() end)

    refresh = function()
        if not fsOk() then
            listLbl:set("executor без readfile/writefile")
            return
        end
        local files = listConfigs()
        if #files == 0 then
            listLbl:set("пусто")
        else
            listLbl:set(table.concat(files, "\n"))
        end
    end
    refresh()
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
    {group = "Visuals",       name = "Bomb",      icon = "bomb"},
    {group = "Visuals",       name = "Interface", icon = "eye"},
    {group = "Miscellaneous", name = "Main",      icon = "main"},
    {group = "Miscellaneous", name = "Configs",   icon = "configs"},
}

local BUILDERS = {
    Ragebot = buildRagebot,
    Legitbot = buildLegitbot,
    Players = buildPlayers,
    Main = buildMain,
    Configs = buildConfigs,
    Interface = buildInterface,
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
    pageTitle.Text = def.name
    currentPage = def
end

local function setSelected(def)
    for _, other in ipairs(PAGES) do
        if other ~= def then
            other.selected = false
            other.btn.BackgroundTransparency = 1
            other.navStroke.Transparency = 1
            other.selBar.Visible = false
            other.nameLbl.TextColor3 = C.dim
            iconTint(other.iconSlot, C.dim)
        end
    end
    def.selected = true
    def.btn.BackgroundTransparency = 0.6
    def.navStroke.Transparency = 0.55
    def.selBar.Visible = true
    def.nameLbl.TextColor3 = C.text
    iconTint(def.iconSlot, C.accent)
    showPage(def)
end

-- построение рейки
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
    if type(writefile) ~= "function" then
        notify("Saved (no writefile)")
        return
    end
    local ok, err = saveConfigAs(configName)
    if ok then
        notify("Config saved: " .. configName)
    else
        notify("Save failed: " .. tostring(err))
    end
end

saveBtn.MouseButton1Click:Connect(saveConfig)

-- forward-декларация: сама функция объявлена в секции API ниже
local unload

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
    openPopup(gearBtn, {"Save config", "Reset HUD", "Unload"}, function(pick)
        if pick == "Save config" then
            saveConfig()
        elseif pick == "Reset HUD" then
            if HUD and HUD.ResetPositions then
                pcall(HUD.ResetPositions)
                notify("HUD: позиции сброшены")
            end
        elseif pick == "Unload" then
            if unload then unload() end
        end
    end, 160)
end)

--=================================================================
--  ПОКАЗ / СКРЫТИЕ
--=================================================================
local opened = true

local function setOpen(state)
    opened = state
    gui.Enabled = state
    Tween:Create(blur, TweenInfo.new(0.2), {Size = state and 18 or 0}):Play()
    if HUD and HUD.SetMenuOpen then pcall(HUD.SetMenuOpen, state) end
end

local uiConn = UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setOpen(not opened)
    elseif input.KeyCode == Enum.KeyCode.Escape and opened then
        setOpen(false)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    setOpen(false)
end)

setOpen(true)

--=================================================================
--  API
--=================================================================
unload = function()
    -- сначала отключаем всё, что живёт на сервисах: после Destroy они бы падали
    pcall(function() if uiConn then uiConn:Disconnect() end end)
    pcall(function() if camWatch then camWatch:Disconnect() end end)
    pcall(function() if camConn then camConn:Disconnect() end end)
    pcall(teardownFeatures)
    pcall(function() if HUD then HUD.Destroy() end end)
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
    SaveConfig = saveConfigAs,
    LoadConfig = loadConfigFrom,
    DeleteConfig = deleteConfig,
    ListConfigs = listConfigs,
    Configs = CONFIG_DIR,
    Unload = unload,
    Toggle = setOpen,
    Pages = pageByName,
    Icons = ICONS,
    SetIcon = setIcon,
    RefreshIcons = refreshIcons,
    Atlas = ATLAS_RECTS,
    SetAtlas = setAtlas,
    Features = FZ,
    ESP = FZ.esp,
    HUD = HUD,
    SetAimbot = FEAT.setAimbot,
    SetAimAssist = FEAT.setAssist,
    SetScaffold = FEAT.setScaffold,
    SetSilentAim = setSilentAim,
    SetHitbox = setHitbox,
    SetESP = setESP,
    SetFly = setFly,
    SetNoclip = setNoclip,
    SetAirstuck = setAirstuck,
    SetGhostFreeze = setGhostFreeze,
    NoclipTeleport = noclipTeleport,
    SetClickTp = setClickTp,
    SetWalkSpeed = setWalkSpeed,
    KillPlayer = killPlayer,
}

getgenv().SpermaHubUI = api
getgenv().NeverloseUI = api  -- старое имя, оставлено для совместимости

-- стартовая страница
setSelected(pageByName.Main or PAGES[1])
notify("SPERMAHUB loaded \u{2022} RShift")
