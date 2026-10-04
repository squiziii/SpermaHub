-- ============================================================
-- ============ CLICK GUI BRIDGE (Voidware-стиль) =============
-- ============================================================
local SHLib = getgenv().shitaroebet

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

-- тосты (либа уже встроена выше)
toastImpl = function(title, msg)
    local t, text = tostring(title or ""), tostring(msg or "")
    pcall(function()
        SHLib:notify({ title = (t ~= "" and (text ~= "" and (t .. " — " .. text) or t) or text), duration = 2.6 })
    end)
end

-- штатный вотермарк либы выключаем (у нас свой pill)
pcall(function() SHLib:setwatermark(false) end)

-- ---------- РЕЕСТР ------
Categories = {}
Pages = {}
CatSelected = nil
local Cfg = {}

-- ---------- КОРЕНЬ GUI ----------
local CGGui = cgNew("ScreenGui", {
    Name = "SpermaHubClickGui",
    ResetOnSpawn = false,
    DisplayOrder = 950,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, LP:WaitForChild("PlayerGui"))

local rootF = cgNew("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 10),
    Size = UDim2.new(0, 6 * 176, 0, 372),
    ZIndex = 2,
}, CGGui)

local CG_OPEN = true
local MODULES = {} -- все модули

-- ---------- КАТЕГОРИЯ → панель ----------
local CAT_ORDER = { Combat=1, Movement=2, Visuals=3, Player=4, Server=5, Miscellaneous=6 }
local curModule = nil

local function addCategoryImpl(title)
    local idx = CAT_ORDER[title] or (#Categories + 10)
    local panel = cgNew("Frame", {
        Name = "Cat_" .. title,
        Position = UDim2.new(0, (idx - 1) * 176, 0, 0),
        Size = UDim2.new(0, 168, 0, 372),
        BackgroundColor3 = CT.panel,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = idx,
        ZIndex = 3,
    }, rootF)
    cgCorner(8, panel)
    cgNew("UIStroke", {Color = CT.line, Transparency = 0.35, Thickness = 1}, panel)

    local head = cgNew("TextLabel", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = CT.header,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = title,
        TextColor3 = CT.text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        ZIndex = 4,
    }, panel)
    cgCorner(8, head)

    -- drag по заголовку
    do
        local dragging, dragStart, startPos
        head.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = inp.Position
                startPos = panel.Position
            end
        end)
        UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UIS.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                local d = inp.Position - dragStart
                panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                           startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    local scroll = cgNew("ScrollingFrame", {
        Position = UDim2.new(0, 5, 0, 32),
        Size = UDim2.new(1, -10, 1, -38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = CT.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 4,
    }, panel)
    listLayout(scroll, 3, true)

    table.insert(Categories, {key = title, panel = panel, scroll = scroll})
end

-- ---------- МОДУЛЬ (page) ----------
local function updModHeader(m)
    local on = false
    if m.enableKey and Cfg[m.enableKey] then
        local ok, v = pcall(Cfg[m.enableKey].get)
        on = ok and v == true
    end
    if m.headerBtn then
        m.headerBtn.BackgroundColor3 = on and CT.rowOn or CT.row
        m.nameLbl.TextColor3 = on and CT.text or CT.dim
    end
end

local function addPageImpl(cat, icon, title)
    local catEntry = nil
    for _, c in ipairs(Categories) do if c.key == cat then catEntry = c break end end
    if not catEntry then addCategoryImpl(cat) for _, c in ipairs(Categories) do if c.key == cat then catEntry = c break end end end

    local m = {
        cat = cat, title = tostring(title), elements = {},
        enableKey = nil, bodyBuilt = false, open = false,
    }
    table.insert(Pages, m)
    table.insert(MODULES, m)
    curModule = m

    local row = cgNew("Frame", {
        Name = "Mod_" .. m.title,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 5,
    }, catEntry.scroll)
    listLayout(row, 2, true)
    m.row = row

    local headerBtn = cgNew("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = CT.row,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 24),
        Text = "",
        ZIndex = 6,
    }, row)
    cgCorner(4, headerBtn)
    m.headerBtn = headerBtn

    local nameLbl = cgNew("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(1, -30, 1, 0),
        Text = m.title,
        TextColor3 = CT.dim,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, headerBtn)
    m.nameLbl = nameLbl

    local gearLbl = cgNew("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -22, 0, 0),
        Size = UDim2.new(0, 22, 1, 0),
        Text = "...",
        TextColor3 = CT.dim,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ZIndex = 7,
    }, headerBtn)

    local body = cgNew("Frame", {
        Visible = false,
        BackgroundColor3 = CT.panel,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 6,
    }, row)
    cgCorner(4, body)
    listLayout(body, 2, true)
    cgNew("UIPadding", {
        PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
        PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3),
    }, body)
    m.body = body

    headerBtn.MouseButton1Click:Connect(function()
        if m.enableKey and Cfg[m.enableKey] then
            local ok, cur = pcall(Cfg[m.enableKey].get)
            if ok then
                local ok2 = pcall(Cfg[m.enableKey].set, not cur)
                if not ok2 then pcall(updModHeader, m) end
            end
            pcall(updModHeader, m)
        else
            body.Visible = not body.Visible
            m.open = body.Visible
        end
    end)
    gearLbl.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            if not m.bodyBuilt then pcall(buildModuleBody, m) m.bodyBuilt = true end
            body.Visible = not body.Visible
            m.open = body.Visible
        end
    end)

    return {__module = m, col1 = nil, col2 = nil}
end

-- колонки как заглушки, настройки будут списком
local function mkCol(m)
    return {__module = m}
end

-- декоратор addPage: учитывает старый формат pg.col1/col2
do
    local raw = addPageImpl
    addPageImpl = function(cat, icon, title)
        local pg = raw(cat, icon, title)
        pg.col1 = mkCol(pg.__module)
        pg.col2 = mkCol(pg.__module)
        return pg
    end
end

local function addPanelImpl(col, title)
    local sec = {title = cleanText(title), module = col.__module}
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

-- ---------- ВИЗУАЛ: построение настроек модуля ----------
local function mkRow(parent, h)
    return cgNew("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = CT.row,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, h),
        Text = "",
        ZIndex = 8,
    }, parent), nil
end

function buildModuleBody(m)
    if m._building then return end
    m._building = true
    for _, el in ipairs(m.elements) do
        if el.kind == "section" then
            local lbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                Text = string.lower(el.title),
                TextColor3 = CT.accent,
                TextTransparency = 0.2,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 8,
            }, m.body)
            lbl.LayoutOrder = #m.body:GetChildren()
        elseif el.kind == "toggle" then
            local row = mkRow(m.body, 22)
            cgCorner(4, row)
            local lbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 7, 0, 0),
                Size = UDim2.new(1, -48, 1, 0),
                Text = el.label,
                TextColor3 = CT.dim,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            }, row)
            local pill = cgNew("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.new(0, 30, 0, 14),
                BackgroundColor3 = CT.line,
                BorderSizePixel = 0,
                ZIndex = 9,
            }, row)
            cgCorner(7, pill)
            local knob = cgNew("Frame", {
                Size = UDim2.new(0, 10, 0, 10),
                Position = UDim2.new(0, 2, 0.5, -5),
                BackgroundColor3 = CT.dim,
                BorderSizePixel = 0,
                ZIndex = 10,
            }, pill)
            cgCorner(5, knob)
            local function upd()
                local on = el.value
                if on then
                    pill.BackgroundColor3 = CT.accent
                    knob.Position = UDim2.new(1, -12, 0.5, -5)
                    knob.BackgroundColor3 = CT.text
                    lbl.TextColor3 = CT.text
                else
                    pill.BackgroundColor3 = CT.line
                    knob.Position = UDim2.new(0, 2, 0.5, -5)
                    knob.BackgroundColor3 = CT.dim
                    lbl.TextColor3 = CT.dim
                end
            end
            el._upd = upd
            row.MouseButton1Click:Connect(function()
                local setFn = el.key and Cfg[el.key] and Cfg[el.key].set
                if setFn then setFn(not el.value) else
                    el.value = not el.value
                    pcall(function() if el.cb then el.cb(el.value) end end)
                    upd()
                end
                if el.module then updModHeader(el.module) end
            end)
            el.key = nil
            upd()
        elseif el.kind == "slider" then
            local row = cgNew("Frame", {
                BackgroundColor3 = CT.row,
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 38),
                ZIndex = 8,
            }, m.body)
            cgCorner(4, row)
            local lbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 7, 0, 2),
                Size = UDim2.new(1, -60, 0, 14),
                Text = el.label,
                TextColor3 = CT.dim,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            }, row)
            local valLbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -60, 0, 2),
                Size = UDim2.new(0, 55, 0, 14),
                Text = tostring(el.value),
                TextColor3 = CT.text,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 9,
            }, row)
            local barBg = cgNew("Frame", {
                Position = UDim2.new(0, 7, 1, -12),
                Size = UDim2.new(1, -14, 0, 5),
                BackgroundColor3 = CT.line,
                BorderSizePixel = 0,
                ZIndex = 9,
            }, row)
            cgCorner(3, barBg)
            local fill = cgNew("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = CT.accent,
                BorderSizePixel = 0,
                ZIndex = 10,
            }, barBg)
            cgCorner(3, fill)
            local barHit = cgNew("TextButton", {
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 7, 1, -16),
                Size = UDim2.new(1, -14, 0, 13),
                Text = "",
                ZIndex = 11,
            }, row)
            local function paint()
                local f = (el.value - el.min) / math.max(1e-6, el.max - el.min)
                fill.Size = UDim2.new(math.clamp(f, 0, 1), 0, 1, 0)
                valLbl.Text = tostring(math.floor(el.value * 100 + 0.5) / 100)
            end
            el._upd = paint
            local dragging = false
            local function applyFromX(x)
                local f = math.clamp((x - barBg.AbsolutePosition.X) / math.max(1, barBg.AbsoluteSize.X), 0, 1)
                local raw = el.min + (el.max - el.min) * f
                local stepped = el.min + math.floor((raw - el.min) / el.step + 0.5) * el.step
                el.value = math.clamp(stepped, el.min, el.max)
                pcall(function() if el.cb then el.cb(el.value) end end)
                paint()
            end
            barHit.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    applyFromX(i.Position.X)
                end
            end)
            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
            UIS.InputChanged:Connect(function(i)
                if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                    applyFromX(i.Position.X)
                end
            end)
            paint()
        elseif el.kind == "dropdown" then
            local row = mkRow(m.body, 22)
            cgCorner(4, row)
            cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 7, 0, 0),
                Size = UDim2.new(0.55, -7, 1, 0),
                Text = el.label,
                TextColor3 = CT.dim,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            }, row)
            local valLbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -7, 0, 0),
                Size = UDim2.new(0.45, 0, 1, 0),
                Text = tostring(el.value),
                TextColor3 = CT.text,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 9,
            }, row)
            el._upd = function() valLbl.Text = tostring(el.value) end
            row.MouseButton1Click:Connect(function()
                local idx = 1
                for i, opt in ipairs(el.options or {}) do
                    if tostring(opt) == tostring(el.value) then idx = i break end
                end
                idx = idx + 1
                if idx > #(el.options or {}) then idx = 1 end
                el.value = tostring(el.options[idx])
                pcall(function() if el.cb then el.cb(el.value) end end)
                if el._upd then el._upd() end
            end)
        elseif el.kind == "keybind" then
            local row = mkRow(m.body, 22)
            cgCorner(4, row)
            cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 7, 0, 0),
                Size = UDim2.new(0.6, -7, 1, 0),
                Text = el.label,
                TextColor3 = CT.dim,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            }, row)
            local valLbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -7, 0, 0),
                Size = UDim2.new(0.4, 0, 1, 0),
                Text = "[" .. (el.value and el.value.Name or "—") .. "]",
                TextColor3 = CT.text,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 9,
            }, row)
            el._upd = function()
                valLbl.Text = "[" .. (el.value and el.value.Name or "—") .. "]"
            end
            row.MouseButton1Click:Connect(function()
                if keyCaptureEl then return end
                keyCaptureEl = el
                valLbl.Text = "[...]"
            end)
        elseif el.kind == "button" then
            local row = mkRow(m.body, 22)
            cgCorner(4, row)
            local lbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = el.label,
                TextColor3 = CT.text,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                ZIndex = 9,
            }, row)
            row.MouseButton1Click:Connect(function()
                pcall(function() if el.cb then el.cb() end end)
            end)
        elseif el.kind == "text" then
            local lbl = cgNew("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                TextWrapped = true,
                Text = el.text,
                Font = Enum.Font.GothamMedium,
                TextSize = 10,
                TextColor3 = CT.dim,
                TextTransparency = 0.25,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 8,
            }, m.body)
            cgNew("UIPadding", {
                PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 2),
            }, lbl)
        elseif el.kind == "plist" then
            local frame = cgNew("Frame", {
                BackgroundColor3 = CT.row,
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, el.height),
                ZIndex = 8,
            }, m.body)
            cgCorner(4, frame)
            local sf = cgNew("ScrollingFrame", {
                Position = UDim2.new(0, 4, 0, 4),
                Size = UDim2.new(1, -8, 1, -8),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = CT.accent,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ZIndex = 9,
            }, frame)
            local ll = Instance.new("UIListLayout")
            ll.Padding = UDim.new(0, 2)
            ll.SortOrder = Enum.SortOrder.LayoutOrder
            ll.Parent = sf
            el._paint = function()
                for _, c in ipairs(sf:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for _, d in ipairs(el.data or {}) do
                    local nm = d.name
                    local sel = (nm == el.selected)
                    local btn = cgNew("TextButton", {
                        AutoButtonColor = false,
                        BackgroundColor3 = sel and CT.accent or CT.row,
                        BackgroundTransparency = sel and 0.6 or 0.5,
                        BorderSizePixel = 0,
                        Size = UDim2.new(1, 0, 0, 20),
                        Text = "  " .. tostring(nm) .. (d.dist and ("   [" .. tostring(d.dist) .. "]") or ""),
                        TextColor3 = sel and CT.text or CT.dim,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 10,
                    }, sf)
                    cgCorner(3, btn)
                    btn.MouseButton1Click:Connect(function()
                        if el.selected == nm then
                            el.selected = nil
                            if el.onConnect then pcall(el.onConnect, nil) end
                        else
                            el.selected = nm
                            if el.onConnect then pcall(el.onConnect, nm) end
                        end
                        if el._paint then el._paint() end
                    end)
                end
            end
            el._paint()
        end
    end
    m._building = false
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

-- ---------- SEARCH ----------
local searchBox = cgNew("TextBox", {
    BackgroundColor3 = CT.panel,
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -16),
    Size = UDim2.new(0, 220, 0, 28),
    PlaceholderText = "Search",
    PlaceholderColor3 = CT.dim,
    Text = "",
    TextColor3 = CT.text,
    Font = Enum.Font.GothamMedium,
    TextSize = 13,
    ClearTextOnFocus = false,
    ZIndex = 100,
}, CGGui)
cgCorner(8, searchBox)
cgNew("UIStroke", {Color = CT.line, Transparency = 0.3, Thickness = 1}, searchBox)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = string.lower(searchBox.Text or "")
    for _, m in ipairs(MODULES) do
        if m.row then
            m.row.Visible = (q == "") or (string.lower(m.title):find(q, 1, true) ~= nil)
        end
    end
end)

-- ---------- RSHIFT: тоггл всего GUI ----------
UIS.InputBegan:Connect(function(inp, gp)
    if inp.KeyCode == Enum.KeyCode.RightShift then
        CG_OPEN = not CG_OPEN
        CGGui.Enabled = CG_OPEN
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
            pcall(function() SHLib:unload() end)
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
        return {__module = m, col1 = mkCol(m), col2 = mkCol(m)}
    end
    return r
end

local function addPanel(col, title)
    local m = col and col.__module
    if m == nil then return {module = nil, __module = nil, dim = true} end
    return {module = m, __module = m, sec = {title = cleanText(title)}}
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
