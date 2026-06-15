local library = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

local TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local TWEEN_SLOW = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

library.Theme = {
    Background = Color3.fromRGB(25, 25, 30),
    TopBar = Color3.fromRGB(20, 20, 24),
    Accent = Color3.fromRGB(130, 80, 255),
    Text = Color3.fromRGB(235, 235, 240),
    SubText = Color3.fromRGB(150, 150, 160),
    ComponentBackground = Color3.fromRGB(35, 35, 42),
    Border = Color3.fromRGB(55, 55, 65),
    ToggleON = Color3.fromRGB(130, 80, 255),
    ToggleOFF = Color3.fromRGB(70, 70, 80),
}

local THEME_DEFAULTS = {}
for k, v in pairs(library.Theme) do THEME_DEFAULTS[k] = v end

library._themeListeners = {}
library._configRegistry = {}
library._activityLog = {}
library._logListeners = {}
library._scriptStart = os.clock()
library._windows = {}

local CONFIG_FOLDER = "MyHubConfigs"

local function hasFileApi()
    return (writefile ~= nil and readfile ~= nil and isfile ~= nil)
end

local function clip(text)
    pcall(function()
        if setclipboard then
            setclipboard(text)
        elseif syn and syn.write_clipboard then
            syn.write_clipboard(text)
        elseif toclipboard then
            toclipboard(text)
        end
    end)
end

local function new(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                inst[k] = v
            end
        end
    end
    if children then
        for _, c in ipairs(children) do
            c.Parent = inst
        end
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function tween(inst, info, props)
    local t = TweenService:Create(inst, info or TWEEN, props)
    t:Play()
    return t
end

local function corner(parent, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius or 6), Parent = parent})
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or library.Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

library._onTheme = function(self, fn)
    pcall(fn)
    table.insert(self._themeListeners, fn)
end

local function applyTheme()
    for _, fn in ipairs(library._themeListeners) do
        pcall(fn)
    end
end

local function logAction(tabName, compName, action, value)
    local entry = {
        timestamp = os.clock(),
        elapsed = os.clock() - library._scriptStart,
        tab = tabName or "?",
        component = compName or "?",
        action = action or "?",
        value = value,
    }
    table.insert(library._activityLog, 1, entry)
    while #library._activityLog > 200 do
        table.remove(library._activityLog)
    end
    for _, fn in ipairs(library._logListeners) do
        pcall(fn, entry)
    end
end

local function getCoreGui()
    local target
    pcall(function()
        if gethui then
            target = gethui()
        end
    end)
    if not target then
        pcall(function()
            target = game:GetService("CoreGui")
        end)
    end
    if not target then
        target = LocalPlayer:WaitForChild("PlayerGui")
    end
    return target
end

local NOTIF_GUI
local notifContainer
local function ensureNotifGui()
    if NOTIF_GUI and NOTIF_GUI.Parent then return end
    NOTIF_GUI = new("ScreenGui", {
        Name = "ProximityPrompts_Notif",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        Parent = getCoreGui(),
    })
    notifContainer = new("Frame", {
        Name = "Container",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -15, 1, -15),
        Size = UDim2.new(0, 300, 1, -30),
        BackgroundTransparency = 1,
        Parent = NOTIF_GUI,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = notifContainer,
    })
end

function library:Notify(opts)
    opts = opts or {}
    ensureNotifGui()
    local T = self.Theme
    local card = new("Frame", {
        BackgroundColor3 = T.ComponentBackground,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = notifContainer,
    })
    corner(card, 8)
    local accent = new("Frame", {
        BackgroundColor3 = T.Accent,
        Size = UDim2.new(0, 4, 1, 0),
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(accent, 8)
    local pad = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 12, 0, 0), Parent = card})
    new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pad})
    new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = pad})
    local title = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = Enum.Font.GothamSemibold,
        Text = opts.title or "Notification",
        TextColor3 = T.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = pad,
    })
    local body = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Enum.Font.Gotham,
        Text = opts.text or "",
        TextColor3 = T.SubText,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        Parent = pad,
    })
    card.Position = UDim2.new(1, 0, 0, 0)
    tween(card, TWEEN_SLOW, {BackgroundTransparency = 0})
    task.delay(opts.duration or 3, function()
        if card and card.Parent then
            tween(card, TWEEN_SLOW, {BackgroundTransparency = 1})
            tween(title, TWEEN_SLOW, {TextTransparency = 1})
            tween(body, TWEEN_SLOW, {TextTransparency = 1})
            task.wait(0.3)
            card:Destroy()
        end
    end)
end

function library:GetUsername() return LocalPlayer.Name end
function library:GetUserId() return LocalPlayer.UserId end
function library:GetPlaceId() return game.PlaceId end
function library:GetJobId() return game.JobId end
function library:Rejoin()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

local WATERMARK_GUI, watermarkFrame, watermarkLabel
function library:SetWatermark(text)
    local T = self.Theme
    if not (WATERMARK_GUI and WATERMARK_GUI.Parent) then
        WATERMARK_GUI = new("ScreenGui", {
            Name = "ProximityPrompts_WM",
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 9998,
            Parent = getCoreGui(),
        })
        watermarkFrame = new("Frame", {
            Position = UDim2.new(0, 10, 0, 10),
            Size = UDim2.new(0, 200, 0, 28),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = T.TopBar,
            Parent = WATERMARK_GUI,
        })
        corner(watermarkFrame, 6)
        local wmStroke = stroke(watermarkFrame, T.Accent, 1, 0)
        watermarkLabel = new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -20, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamSemibold,
            Text = text or "",
            TextColor3 = T.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = watermarkFrame,
        })
        new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = watermarkLabel})
        self:_onTheme(function()
            watermarkFrame.BackgroundColor3 = self.Theme.TopBar
            wmStroke.Color = self.Theme.Accent
            watermarkLabel.TextColor3 = self.Theme.Text
        end)
    else
        watermarkLabel.Text = text or ""
    end
end
function library:HideWatermark()
    if WATERMARK_GUI then WATERMARK_GUI.Enabled = false end
end
function library:ShowWatermark()
    if WATERMARK_GUI then WATERMARK_GUI.Enabled = true end
end

local function encodeValue(v)
    local t = typeof(v)
    if t == "Color3" then
        return {__t = "Color3", r = math.floor(v.R * 255 + 0.5), g = math.floor(v.G * 255 + 0.5), b = math.floor(v.B * 255 + 0.5)}
    elseif t == "EnumItem" then
        return {__t = "KeyCode", name = v.Name}
    elseif t == "table" then
        local out = {}
        for k, val in pairs(v) do
            out[tostring(k)] = encodeValue(val)
        end
        return {__t = "table", data = out}
    else
        return {__t = "raw", data = v}
    end
end

local function decodeValue(v)
    if typeof(v) ~= "table" or not v.__t then return v end
    if v.__t == "Color3" then
        return Color3.fromRGB(v.r, v.g, v.b)
    elseif v.__t == "KeyCode" then
        return Enum.KeyCode[v.name] or Enum.KeyCode.Unknown
    elseif v.__t == "table" then
        local out = {}
        for k, val in pairs(v.data) do
            out[k] = decodeValue(val)
        end
        return out
    elseif v.__t == "raw" then
        return v.data
    end
    return v
end

library._suppressRegister = false
function library:_register(id, getter, setter)
    if self._suppressRegister then return end
    self._configRegistry[id] = {get = getter, set = setter}
end

local function buildConfigTable()
    local data = {}
    for id, c in pairs(library._configRegistry) do
        local ok, val = pcall(c.get)
        if ok then
            data[id] = encodeValue(val)
        end
    end
    return data
end

local function applyConfigTable(data)
    for id, enc in pairs(data) do
        local c = library._configRegistry[id]
        if c then
            pcall(c.set, decodeValue(enc))
        end
    end
end

library._memConfigs = {}

local function configPath(name)
    return CONFIG_FOLDER .. "/" .. name .. ".json"
end

function library:SaveConfig(name)
    name = name or "default"
    local data = buildConfigTable()
    self._memConfigs[name] = data
    local json = HttpService:JSONEncode(data)
    if hasFileApi() then
        pcall(function()
            if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
            writefile(configPath(name), json)
        end)
    end
    return json
end

function library:LoadConfig(name)
    name = name or "default"
    local data = self._memConfigs[name]
    if not data and hasFileApi() then
        pcall(function()
            if isfile(configPath(name)) then
                data = HttpService:JSONDecode(readfile(configPath(name)))
            end
        end)
    end
    if not data then return false end
    applyConfigTable(data)
    return true
end

function library:DeleteConfig(name)
    self._memConfigs[name] = nil
    if hasFileApi() then
        pcall(function()
            if isfile(configPath(name)) then delfile(configPath(name)) end
        end)
    end
end

function library:ListConfigs()
    local names = {}
    local seen = {}
    for k in pairs(self._memConfigs) do
        if not seen[k] then seen[k] = true table.insert(names, k) end
    end
    if hasFileApi() then
        pcall(function()
            if isfolder(CONFIG_FOLDER) then
                for _, f in ipairs(listfiles(CONFIG_FOLDER)) do
                    local n = f:match("([^/\\]+)%.json$")
                    if n and not seen[n] then seen[n] = true table.insert(names, n) end
                end
            end
        end)
    end
    return names
end

function library:ExportConfig(name)
    name = name or "default"
    local data = self._memConfigs[name] or buildConfigTable()
    return HttpService:JSONEncode(data)
end

function library:ImportConfig(jsonString)
    local ok, data = pcall(function() return HttpService:JSONDecode(jsonString) end)
    if ok and type(data) == "table" then
        applyConfigTable(data)
        return true
    end
    return false
end

function library:GetActivityLog() return self._activityLog end
function library:ClearLog()
    self._activityLog = {}
    for _, fn in ipairs(self._logListeners) do pcall(fn, nil) end
end
function library:ExportLog()
    local lines = {}
    for i = #self._activityLog, 1, -1 do
        local e = self._activityLog[i]
        local valStr = e.value
        if typeof(valStr) == "Color3" then
            valStr = string.format("(%d,%d,%d)", valStr.R * 255, valStr.G * 255, valStr.B * 255)
        elseif type(valStr) == "table" then
            valStr = HttpService:JSONEncode(valStr)
        else
            valStr = tostring(valStr)
        end
        table.insert(lines, string.format("[%.2fs] %s | %s | %s | %s", e.elapsed, e.tab, e.component, e.action, valStr))
    end
    return table.concat(lines, "\n")
end

local Tab = {}
Tab.__index = Tab

local buildConfigTab, buildLogTab, attachSearch

local function canvasResize(page)
    local layout = page:FindFirstChildOfClass("UIListLayout")
    if not layout then return end
    local function upd()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(upd)
    upd()
end

local function makeRow(tab, height, autoY)
    local container = new("Frame", {
        Name = "Row",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        Parent = tab.page,
    })
    if autoY then
        container.AutomaticSize = Enum.AutomaticSize.Y
    end
    local comp = {}
    comp.container = container
    comp._tab = tab
    if not library._suppressRegister and tab.window and tab.window._searchIndex then
        table.insert(tab.window._searchIndex, {container = container, tab = tab})
    end
    comp._visConds = {}
    comp._listeners = {}
    comp._height = height
    comp._autoY = autoY
    comp._visible = true
    function comp:_onChange(fn) table.insert(self._listeners, fn) end
    function comp:_fireChange(v)
        for _, fn in ipairs(self._listeners) do pcall(fn, v) end
    end
    function comp:Show()
        self._visible = true
        self.container.Visible = true
        if self._autoY then
            self.container.Size = UDim2.new(1, 0, 0, self._height)
            self.container.AutomaticSize = Enum.AutomaticSize.Y
        else
            self.container.Size = UDim2.new(1, 0, 0, self._height)
        end
    end
    function comp:Hide()
        self._visible = false
        self.container.AutomaticSize = Enum.AutomaticSize.None
        self.container.Size = UDim2.new(1, 0, 0, 0)
        self.container.Visible = false
    end
    function comp:Remove() self.container:Destroy() end
    function comp:VisibleWhen(other, condFn)
        table.insert(self._visConds, {other = other, fn = condFn})
        local function update()
            local vis = true
            for _, c in ipairs(self._visConds) do
                local val = c.other.__getValue and c.other:__getValue() or nil
                if not c.fn(val) then vis = false break end
            end
            if vis then self:Show() else self:Hide() end
        end
        if other._onChange then other:_onChange(update) end
        update()
        return self
    end
    return comp, container
end

local function wrapCallback(tab, label, action, cb)
    return function(value)
        logAction(tab.name, label, action, value)
        if cb then pcall(cb, value) end
    end
end

function Tab:Open()
    for _, t in ipairs(self.window._tabs) do
        t.page.Visible = false
        if t.button then
            tween(t.button, TWEEN, {BackgroundColor3 = library.Theme.ComponentBackground})
            tween(t.buttonLabel, TWEEN, {TextColor3 = library.Theme.SubText})
        end
    end
    self.page.Visible = true
    self.window._activeTab = self
    if self.button then
        tween(self.button, TWEEN, {BackgroundColor3 = library.Theme.Accent})
        tween(self.buttonLabel, TWEEN, {TextColor3 = library.Theme.Text})
    end
end
function Tab:Show() self.page.Visible = true end
function Tab:Hide() self.page.Visible = false end
function Tab:Remove()
    if self.button then self.button:Destroy() end
    self.page:Destroy()
    for i, t in ipairs(self.window._tabs) do
        if t == self then table.remove(self.window._tabs, i) break end
    end
end

local Window = {}
Window.__index = Window

function library:CreateWindow(options)
    options = options or {}
    local T = self.Theme
    local gui = new("ScreenGui", {
        Name = "ProximityPrompts",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9990,
        Parent = getCoreGui(),
    })

    local main = new("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 500, 0, 350),
        BackgroundColor3 = T.Background,
        ClipsDescendants = true,
        Parent = gui,
    })
    corner(main, 10)
    local mainStroke = stroke(main, T.Border, 1, 1)

    local topbar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.TopBar,
        BorderSizePixel = 0,
        Parent = main,
    })
    corner(topbar, 10)
    new("Frame", {BackgroundColor3 = T.TopBar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10), Parent = topbar})

    local ghostDot = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(0, 20, 1, 0),
        Font = Enum.Font.GothamSemibold,
        Text = "•",
        TextColor3 = T.Accent,
        TextSize = 20,
        TextTransparency = 1,
        Parent = topbar,
    })

    local titleLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -90, 1, 0),
        Font = Enum.Font.GothamSemibold,
        Text = options.title or "MyHub",
        TextColor3 = T.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topbar,
    })

    local closeBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundColor3 = T.ComponentBackground,
        Text = "X",
        Font = Enum.Font.GothamSemibold,
        TextColor3 = T.Text,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = topbar,
    })
    corner(closeBtn, 6)
    local minBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -40, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundColor3 = T.ComponentBackground,
        Text = "-",
        Font = Enum.Font.GothamSemibold,
        TextColor3 = T.Text,
        TextSize = 16,
        AutoButtonColor = false,
        Parent = topbar,
    })
    corner(minBtn, 6)

    local searchHolder = new("Frame", {
        Name = "SearchHolder",
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
        Parent = main,
    })
    local searchBox = new("TextBox", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -20, 0, 26),
        BackgroundColor3 = T.ComponentBackground,
        Font = Enum.Font.Gotham,
        PlaceholderText = "Search components...",
        Text = "",
        TextColor3 = T.Text,
        PlaceholderColor3 = T.SubText,
        TextSize = 13,
        ClearTextOnFocus = false,
        Parent = searchHolder,
    })
    corner(searchBox, 6)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = searchBox})

    local tabBarHolder = new("Frame", {
        Name = "TabBar",
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = T.TopBar,
        BorderSizePixel = 0,
        Parent = main,
    })
    local tabScroll = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        Parent = tabBarHolder,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = tabScroll,
    })
    new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = tabScroll})

    local contentHolder = new("Frame", {
        Name = "Content",
        Position = UDim2.new(0, 0, 0, 66),
        Size = UDim2.new(1, 0, 1, -66),
        BackgroundTransparency = 1,
        Parent = main,
    })

    local window = setmetatable({}, Window)
    window.gui = gui
    window.main = main
    window.mainStroke = mainStroke
    window.topbar = topbar
    window.titleLabel = titleLabel
    window.contentHolder = contentHolder
    window.tabScroll = tabScroll
    window.tabBarHolder = tabBarHolder
    window.searchHolder = searchHolder
    window.searchBox = searchBox
    window.ghostDot = ghostDot
    window._tabs = {}
    window._activeTab = nil
    window._visible = true
    window._ghost = false
    window._ghostKey = nil
    window._searchEnabled = false
    window._searchIndex = {}
    window._ghostStore = {}
    window._tabBarBaseY = 36
    window._contentBaseY = 66
    table.insert(library._windows, window)

    local dragging, dragStart, startPos = false, nil, nil
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    closeBtn.MouseButton1Click:Connect(function() window:Remove() end)
    minBtn.MouseButton1Click:Connect(function() window:Toggle() end)
    closeBtn.MouseEnter:Connect(function() if not window._ghost then tween(closeBtn, TWEEN, {BackgroundColor3 = Color3.fromRGB(200, 60, 60)}) end end)
    closeBtn.MouseLeave:Connect(function() if not window._ghost then tween(closeBtn, TWEEN, {BackgroundColor3 = library.Theme.ComponentBackground}) end end)

    if options.key then
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == options.key then
                window:Toggle()
            end
        end)
    end

    self:_onTheme(function()
        local th = self.Theme
        main.BackgroundColor3 = th.Background
        topbar.BackgroundColor3 = th.TopBar
        tabBarHolder.BackgroundColor3 = th.TopBar
        titleLabel.TextColor3 = th.Text
        mainStroke.Color = th.Border
        ghostDot.TextColor3 = th.Accent
    end)

    if not options.noExtraTabs then
        window._configTab = buildConfigTab(window)
        window._logTab = buildLogTab(window)
    end

    return window
end

function Window:NewTab(name)
    local T = library.Theme
    local btn = new("TextButton", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = T.ComponentBackground,
        Text = "",
        AutoButtonColor = false,
        Parent = self.tabScroll,
    })
    corner(btn, 6)
    local btnLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Enum.Font.GothamSemibold,
        Text = name,
        TextColor3 = T.SubText,
        TextSize = 13,
        Parent = btn,
    })
    new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = btnLabel})

    local page = new("ScrollingFrame", {
        Name = name,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        ClipsDescendants = true,
        Parent = self.contentHolder,
    })
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = page})
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), Parent = page})
    canvasResize(page)

    local tab = setmetatable({}, Tab)
    tab.name = name
    tab.window = self
    tab.page = page
    tab.button = btn
    tab.buttonLabel = btnLabel
    tab.components = {}
    table.insert(self._tabs, tab)

    btn.MouseButton1Click:Connect(function() tab:Open() end)
    library:_onTheme(function()
        if self._activeTab ~= tab then
            btn.BackgroundColor3 = library.Theme.ComponentBackground
            btnLabel.TextColor3 = library.Theme.SubText
        end
    end)

    if not self._activeTab then
        tab:Open()
    end
    return tab
end

function Window:SetTitle(text) self.titleLabel.Text = text end
function Window:Toggle()
    self._visible = not self._visible
    self.main.Visible = self._visible
end
function Window:Remove()
    self.gui:Destroy()
    for i, w in ipairs(library._windows) do
        if w == self then table.remove(library._windows, i) break end
    end
end

function Tab:NewButton(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 32)
    local T = library.Theme
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.ComponentBackground,
        Font = Enum.Font.GothamSemibold,
        Text = opts.text or "Button",
        TextColor3 = T.Text,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = container,
    })
    corner(btn, 6)
    local bStroke = stroke(btn, T.Border, 1, 0)
    local cb = wrapCallback(self, opts.text or "Button", "Button", opts.callback)
    btn.MouseEnter:Connect(function() if not self.window._ghost then tween(btn, TWEEN, {BackgroundColor3 = library.Theme.Accent}) end end)
    btn.MouseLeave:Connect(function() if not self.window._ghost then tween(btn, TWEEN, {BackgroundColor3 = library.Theme.ComponentBackground}) end end)
    btn.MouseButton1Click:Connect(function()
        tween(btn, TweenInfo.new(0.08), {BackgroundColor3 = library.Theme.Text})
        task.delay(0.1, function() tween(btn, TWEEN, {BackgroundColor3 = library.Theme.ComponentBackground}) end)
        cb()
    end)
    comp._setText = function(t) btn.Text = t end
    library:_onTheme(function()
        btn.BackgroundColor3 = library.Theme.ComponentBackground
        btn.TextColor3 = library.Theme.Text
        bStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {btn, bStroke}
    return comp
end

function Tab:NewToggle(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 32)
    local T = library.Theme
    local frame = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -70, 1, 0), Font = Enum.Font.Gotham, Text = opts.text or "Toggle", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
    local pill = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 40, 0, 20), BackgroundColor3 = T.ToggleOFF, Parent = frame})
    corner(pill, 10)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = pill})
    corner(knob, 8)

    local state = opts.default and true or false
    local cb = wrapCallback(self, opts.text or "Toggle", "Toggle", opts.callback)
    local function visual()
        if state then
            tween(pill, TWEEN, {BackgroundColor3 = library.Theme.ToggleON})
            tween(knob, TWEEN, {Position = UDim2.new(1, -18, 0.5, 0)})
        else
            tween(pill, TWEEN, {BackgroundColor3 = library.Theme.ToggleOFF})
            tween(knob, TWEEN, {Position = UDim2.new(0, 2, 0.5, 0)})
        end
    end
    visual()
    local btn = new("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Parent = frame})
    function comp:SetState(v, silent)
        state = v and true or false
        visual()
        self:_fireChange(state)
        if not silent then cb(state) end
    end
    function comp:GetState() return state end
    comp.__getValue = function() return state end
    btn.MouseButton1Click:Connect(function() comp:SetState(not state) end)

    library:_register(self.name .. "::" .. (opts.text or "Toggle"), function() return state end, function(v) comp:SetState(v) end)
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        fStroke.Color = library.Theme.Border
        visual()
    end)
    comp._ghostApply = {frame, fStroke, label}
    return comp
end

function Tab:NewSlider(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 44)
    local T = library.Theme
    local minV, maxV = opts.min or 0, opts.max or 100
    local value = math.clamp(opts.default or minV, minV, maxV)
    local suffix = opts.suffix or ""
    local frame = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0, 16), Font = Enum.Font.Gotham, Text = opts.text or "Slider", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
    local valLabel = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(1, -70, 0, 4), Size = UDim2.new(0, 60, 0, 16), Font = Enum.Font.GothamSemibold, Text = tostring(value) .. suffix, TextColor3 = T.Accent, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = frame})
    local bar = new("Frame", {Position = UDim2.new(0, 10, 1, -16), Size = UDim2.new(1, -20, 0, 6), BackgroundColor3 = T.ToggleOFF, Parent = frame})
    corner(bar, 3)
    local fill = new("Frame", {Size = UDim2.new((value - minV) / (maxV - minV), 0, 1, 0), BackgroundColor3 = T.Accent, Parent = bar})
    corner(fill, 3)

    local cb = wrapCallback(self, opts.text or "Slider", "Slider", opts.callback)
    local function setVal(v, silent)
        v = math.clamp(math.floor(v + 0.5), minV, maxV)
        value = v
        valLabel.Text = tostring(v) .. suffix
        fill.Size = UDim2.new((v - minV) / (maxV - minV), 0, 1, 0)
        comp:_fireChange(v)
        if not silent then cb(v) end
    end
    function comp:SetValue(v) setVal(v) end
    function comp:GetValue() return value end
    comp.__getValue = function() return value end

    local dragging = false
    local function fromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        setVal(minV + rel * (maxV - minV))
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    library:_register(self.name .. "::" .. (opts.text or "Slider"), function() return value end, function(v) setVal(v) end)
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        valLabel.TextColor3 = library.Theme.Accent
        bar.BackgroundColor3 = library.Theme.ToggleOFF
        fill.BackgroundColor3 = library.Theme.Accent
        fStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {frame, fStroke, label, valLabel}
    return comp
end

function Tab:NewLabel(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 22, true)
    local T = library.Theme
    local label = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.Gotham, Text = opts.text or "Label", TextColor3 = T.SubText, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = container})
    function comp:SetText(t) label.Text = t end
    library:_onTheme(function() label.TextColor3 = library.Theme.SubText end)
    comp._ghostApply = {label}
    return comp
end

function Tab:NewSeparator()
    local comp, container = makeRow(self, 9)
    local T = library.Theme
    local line = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, -8, 0, 1), BackgroundColor3 = T.Border, BorderSizePixel = 0, Parent = container})
    library:_onTheme(function() line.BackgroundColor3 = library.Theme.Border end)
    comp._ghostApply = {line}
    return comp
end

function Tab:NewTextBox(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 32)
    local T = library.Theme
    local frame = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.45, -10, 1, 0), Font = Enum.Font.Gotham, Text = opts.text or "Input", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
    local box = new("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.5, -10, 0, 22), BackgroundColor3 = T.Background, Font = Enum.Font.Gotham, PlaceholderText = opts.placeholder or "", Text = opts.default or "", TextColor3 = T.Text, PlaceholderColor3 = T.SubText, TextSize = 12, ClearTextOnFocus = false, Parent = frame})
    corner(box, 5)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box})

    local value = opts.default or ""
    local cb = wrapCallback(self, opts.text or "Input", "TextBox", opts.callback)
    box.FocusLost:Connect(function()
        value = box.Text
        comp:_fireChange(value)
        cb(value)
    end)
    function comp:SetValue(v) value = tostring(v) box.Text = value comp:_fireChange(value) end
    function comp:GetValue() return value end
    comp.__getValue = function() return value end

    library:_register(self.name .. "::" .. (opts.text or "Input"), function() return value end, function(v) box.Text = tostring(v) value = tostring(v) cb(value) end)
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        box.BackgroundColor3 = library.Theme.Background
        box.TextColor3 = library.Theme.Text
        fStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {frame, fStroke, label, box}
    return comp
end

function Tab:NewParagraph(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 40, true)
    local T = library.Theme
    local frame = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = frame})
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = frame})
    local title = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamSemibold, Text = opts.title or "Title", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = frame})
    local body = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham, Text = opts.text or "", TextColor3 = T.SubText, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = frame})
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        title.TextColor3 = library.Theme.Text
        body.TextColor3 = library.Theme.SubText
        fStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {frame, fStroke, title, body}
    return comp
end

function Tab:NewProgressBar(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 40)
    local T = library.Theme
    local frame = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -60, 0, 16), Font = Enum.Font.Gotham, Text = opts.text or "Progress", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
    local pctLabel = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(1, -50, 0, 4), Size = UDim2.new(0, 40, 0, 16), Font = Enum.Font.GothamSemibold, Text = "0%", TextColor3 = T.Accent, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = frame})
    local bar = new("Frame", {Position = UDim2.new(0, 10, 1, -14), Size = UDim2.new(1, -20, 0, 6), BackgroundColor3 = T.ToggleOFF, Parent = frame})
    corner(bar, 3)
    local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Accent, Parent = bar})
    corner(fill, 3)
    local value = math.clamp(opts.value or 0, 0, 100)
    fill.Size = UDim2.new(value / 100, 0, 1, 0)
    pctLabel.Text = math.floor(value) .. "%"
    function comp:SetValue(v)
        value = math.clamp(v, 0, 100)
        tween(fill, TWEEN, {Size = UDim2.new(value / 100, 0, 1, 0)})
        pctLabel.Text = math.floor(value) .. "%"
    end
    function comp:GetValue() return value end
    function comp:SetText(t) label.Text = t end
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        pctLabel.TextColor3 = library.Theme.Accent
        bar.BackgroundColor3 = library.Theme.ToggleOFF
        fill.BackgroundColor3 = library.Theme.Accent
        fStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {frame, fStroke, label, pctLabel}
    return comp
end

function Tab:NewNumberInput(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 32)
    local T = library.Theme
    local minV = opts.min or 0
    local maxV = opts.max or 1000
    local step = opts.step or 1
    local value = math.clamp(opts.default or minV, minV, maxV)
    local frame = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.5, -10, 1, 0), Font = Enum.Font.Gotham, Text = opts.text or "Number", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
    local minus = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -98, 0.5, 0), Size = UDim2.new(0, 22, 0, 22), BackgroundColor3 = T.Background, Text = "-", Font = Enum.Font.GothamSemibold, TextColor3 = T.Text, TextSize = 16, AutoButtonColor = false, Parent = frame})
    corner(minus, 5)
    local box = new("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -32, 0.5, 0), Size = UDim2.new(0, 60, 0, 22), BackgroundColor3 = T.Background, Font = Enum.Font.Gotham, Text = tostring(value), TextColor3 = T.Text, TextSize = 12, ClearTextOnFocus = false, Parent = frame})
    corner(box, 5)
    local plus = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 22, 0, 22), BackgroundColor3 = T.Background, Text = "+", Font = Enum.Font.GothamSemibold, TextColor3 = T.Text, TextSize = 16, AutoButtonColor = false, Parent = frame})
    corner(plus, 5)

    local cb = wrapCallback(self, opts.text or "Number", "NumberInput", opts.callback)
    local function setVal(v, silent)
        v = math.clamp(v, minV, maxV)
        value = v
        box.Text = tostring(v)
        comp:_fireChange(v)
        if not silent then cb(v) end
    end
    function comp:SetValue(v) setVal(v) end
    function comp:GetValue() return value end
    comp.__getValue = function() return value end
    minus.MouseButton1Click:Connect(function() setVal(value - step) end)
    plus.MouseButton1Click:Connect(function() setVal(value + step) end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then setVal(n) else box.Text = tostring(value) end
    end)
    library:_register(self.name .. "::" .. (opts.text or "Number"), function() return value end, function(v) setVal(v) end)
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        fStroke.Color = library.Theme.Border
        for _, b in ipairs({minus, plus, box}) do b.BackgroundColor3 = library.Theme.Background b.TextColor3 = library.Theme.Text end
    end)
    comp._ghostApply = {frame, fStroke, label, box, minus, plus}
    return comp
end

local function makeBindComponent(self, opts, gamepadOnly, action)
    local comp, container = makeRow(self, 32)
    local T = library.Theme
    local frame = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -110, 1, 0), Font = Enum.Font.Gotham, Text = opts.text or "Bind", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
    local key = opts.default or Enum.KeyCode.Unknown
    local consoleNames = {ButtonX = "X", ButtonY = "Y", ButtonA = "A", ButtonB = "B", ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT", ButtonSelect = "Select", ButtonStart = "Start"}
    local function keyText(k)
        if gamepadOnly and consoleNames[k.Name] then return consoleNames[k.Name] end
        return k.Name
    end
    local btn = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 90, 0, 22), BackgroundColor3 = T.Background, Font = Enum.Font.GothamSemibold, Text = keyText(key), TextColor3 = T.Accent, TextSize = 12, AutoButtonColor = false, Parent = frame})
    corner(btn, 5)

    local cb = wrapCallback(self, opts.text or "Bind", action, opts.callback)
    local listening = false
    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
    end)
    UserInputService.InputBegan:Connect(function(input, gp)
        if listening then
            local isGamepad = input.UserInputType == Enum.UserInputType.Gamepad1
            if gamepadOnly and not isGamepad then return end
            if not gamepadOnly and input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                key = input.KeyCode
                btn.Text = keyText(key)
                listening = false
                comp:_fireChange(key)
            end
            return
        end
        if gp and not gamepadOnly then return end
        if input.KeyCode == key and key ~= Enum.KeyCode.Unknown then
            cb(key)
        end
    end)
    function comp:GetKey() return key end
    function comp:SetKey(k) key = k btn.Text = keyText(k) comp:_fireChange(k) end
    comp.__getValue = function() return key end
    library:_register(self.name .. "::" .. (opts.text or "Bind"), function() return key end, function(k) comp:SetKey(k) end)
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        btn.BackgroundColor3 = library.Theme.Background
        btn.TextColor3 = library.Theme.Accent
        fStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {frame, fStroke, label, btn}
    return comp
end

function Tab:NewKeybind(opts) return makeBindComponent(self, opts or {}, false, "Keybind") end
function Tab:NewGamepadBind(opts) return makeBindComponent(self, opts or {}, true, "GamepadBind") end

local closeActiveDropdown = nil

local function dropdownBase(self, opts, multi, searchable)
    local comp, container = makeRow(self, 30)
    container.ClipsDescendants = true
    local T = library.Theme
    local header = new("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.ComponentBackground, Text = "", AutoButtonColor = false, Parent = container})
    corner(header, 6)
    local fStroke = stroke(header, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.5, -10, 1, 0), Font = Enum.Font.Gotham, Text = opts.text or "Dropdown", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
    local sel = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -28, 1, 0), Font = Enum.Font.Gotham, Text = "", TextColor3 = T.SubText, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = header})
    local arrow = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 16, 1, 0), Font = Enum.Font.GothamSemibold, Text = "v", TextColor3 = T.Accent, TextSize = 12, Parent = header})

    local listHolder = new("Frame", {Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = T.Background, Parent = container})
    corner(listHolder, 6)
    local searchBox
    local listY0 = 0
    if searchable then
        searchBox = new("TextBox", {Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0, 22), BackgroundColor3 = T.ComponentBackground, Font = Enum.Font.Gotham, PlaceholderText = "Search...", Text = "", TextColor3 = T.Text, PlaceholderColor3 = T.SubText, TextSize = 12, ClearTextOnFocus = false, Parent = listHolder})
        corner(searchBox, 5)
        new("UIPadding", {PaddingLeft = UDim.new(0, 6), Parent = searchBox})
        listY0 = 28
    end
    local optScroll = new("ScrollingFrame", {Position = UDim2.new(0, 4, 0, 4 + listY0), Size = UDim2.new(1, -8, 1, -8 - listY0), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(0, 0, 0, 0), Parent = listHolder})
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = optScroll})

    local options = opts.options or {}
    local open = false
    local selected = multi and {} or (opts.default or options[1])
    if multi and opts.default then
        for _, v in ipairs(opts.default) do selected[v] = true end
    end

    local function selText()
        if multi then
            local n = 0
            for _, v in pairs(selected) do if v then n = n + 1 end end
            sel.Text = n .. " selected"
        else
            sel.Text = tostring(selected or "")
        end
    end

    local function listHeight()
        local visible = 0
        for _, b in ipairs(optScroll:GetChildren()) do
            if b:IsA("TextButton") and b.Visible then visible = visible + 1 end
        end
        local h = math.min(visible * 24, 130)
        return h + 8 + listY0
    end

    local function setOpenState(v)
        open = v
        if open then
            if closeActiveDropdown and closeActiveDropdown ~= nil then
                local prev = closeActiveDropdown
                closeActiveDropdown = nil
                if prev then prev() end
            end
            local lh = listHeight()
            comp._height = 30 + lh + 4
            listHolder.Size = UDim2.new(1, 0, 0, lh)
            container.Size = UDim2.new(1, 0, 0, comp._height)
            arrow.Text = "^"
            closeActiveDropdown = function()
                open = false
                comp._height = 30
                container.Size = UDim2.new(1, 0, 0, 30)
                listHolder.Size = UDim2.new(1, 0, 0, 0)
                arrow.Text = "v"
            end
        else
            comp._height = 30
            container.Size = UDim2.new(1, 0, 0, 30)
            listHolder.Size = UDim2.new(1, 0, 0, 0)
            arrow.Text = "v"
            closeActiveDropdown = nil
        end
    end

    local cb = wrapCallback(self, opts.text or "Dropdown", multi and "MultiDropdown" or "Dropdown", opts.callback)
    local rebuild

    local function onPick(optName)
        if multi then
            selected[optName] = not selected[optName]
            selText()
            local list = {}
            for k, v in pairs(selected) do if v then table.insert(list, k) end end
            comp:_fireChange(list)
            cb(list)
            rebuild(true)
        else
            selected = optName
            selText()
            comp:_fireChange(selected)
            cb(selected)
            setOpenState(false)
        end
    end

    rebuild = function(keepOpen)
        for _, c in ipairs(optScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local filter = searchBox and searchBox.Text:lower() or ""
        for i, optName in ipairs(options) do
            local show = filter == "" or tostring(optName):lower():find(filter, 1, true) ~= nil
            local ob = new("TextButton", {Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = T.ComponentBackground, Font = Enum.Font.Gotham, Text = "", TextColor3 = T.Text, TextSize = 12, AutoButtonColor = false, LayoutOrder = i, Visible = show, Parent = optScroll})
            corner(ob, 4)
            local checkTxt = ""
            if multi then checkTxt = (selected[optName] and "[x] " or "[ ] ") end
            new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -16, 1, 0), Font = Enum.Font.Gotham, Text = checkTxt .. tostring(optName), TextColor3 = (not multi and selected == optName) and T.Accent or T.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = ob})
            ob.MouseButton1Click:Connect(function() onPick(optName) end)
        end
        optScroll.CanvasSize = UDim2.new(0, 0, 0, optScroll:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize.Y + 4)
        if keepOpen and open then
            local lh = listHeight()
            comp._height = 30 + lh + 4
            listHolder.Size = UDim2.new(1, 0, 0, lh)
            container.Size = UDim2.new(1, 0, 0, comp._height)
        end
    end
    rebuild()
    selText()

    header.MouseButton1Click:Connect(function() setOpenState(not open) end)
    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function() rebuild(true) end)
    end

    if multi then
        function comp:GetSelected()
            local list = {}
            for k, v in pairs(selected) do if v then table.insert(list, k) end end
            return list
        end
        function comp:SetSelected(t)
            selected = {}
            for _, v in ipairs(t) do selected[v] = true end
            selText() rebuild(true) comp:_fireChange(self:GetSelected())
        end
        comp.__getValue = function() return comp:GetSelected() end
        library:_register(self.name .. "::" .. (opts.text or "Dropdown"), function() return comp:GetSelected() end, function(t) comp:SetSelected(t) cb(comp:GetSelected()) end)
    else
        function comp:GetSelected() return selected end
        function comp:SetOptions(t) options = t rebuild(true) end
        comp.__getValue = function() return selected end
        library:_register(self.name .. "::" .. (opts.text or "Dropdown"), function() return selected end, function(v) selected = v selText() rebuild(true) cb(v) end)
    end
    if not multi then
        function comp:SetOptions(t) options = t if selected and not table.find(t, selected) then selected = t[1] end selText() rebuild(true) end
    else
        function comp:SetOptions(t) options = t rebuild(true) end
    end

    library:_onTheme(function()
        header.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        sel.TextColor3 = library.Theme.SubText
        arrow.TextColor3 = library.Theme.Accent
        listHolder.BackgroundColor3 = library.Theme.Background
        fStroke.Color = library.Theme.Border
        rebuild(true)
    end)
    comp._ghostApply = {header, fStroke, label, sel, arrow}
    return comp
end

function Tab:NewDropdown(opts) return dropdownBase(self, opts or {}, false, false) end
function Tab:NewMultiDropdown(opts) return dropdownBase(self, opts or {}, true, false) end
function Tab:NewSearchableDropdown(opts) return dropdownBase(self, opts or {}, false, true) end

function Tab:NewCheckboxGroup(opts)
    opts = opts or {}
    local optionList = opts.options or {}
    local rowH = 24
    local headerH = 24
    local total = headerH + #optionList * (rowH + 2) + 6
    local comp, container = makeRow(self, total)
    local T = library.Theme
    local frame = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4), Parent = frame})
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = frame})
    local header = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, headerH), Font = Enum.Font.GothamSemibold, Text = opts.text or "Checkboxes", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = frame})

    local states = {}
    local boxes = {}
    local cb = wrapCallback(self, opts.text or "Checkboxes", "CheckboxGroup", opts.callback)
    local function refresh()
        for label, on in pairs(states) do
            local b = boxes[label]
            if b then
                b.tick.Text = on and "x" or ""
                b.tick.BackgroundColor3 = on and library.Theme.Accent or library.Theme.Background
            end
        end
    end
    local function fire()
        comp:_fireChange(states)
        cb(states)
    end
    for i, o in ipairs(optionList) do
        states[o.label] = o.default and true or false
        local row = new("TextButton", {Size = UDim2.new(1, 0, 0, rowH), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = frame})
        local tick = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = T.Background, Parent = row})
        corner(tick, 4)
        local tickLabel = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamSemibold, Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12, Parent = tick})
        local lbl = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -24, 1, 0), Font = Enum.Font.Gotham, Text = o.label, TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
        boxes[o.label] = {tick = tickLabel, lbl = lbl, box = tick}
        boxes[o.label].tick = tickLabel
        boxes[o.label].box = tick
        row.MouseButton1Click:Connect(function()
            states[o.label] = not states[o.label]
            tickLabel.Text = states[o.label] and "x" or ""
            tick.BackgroundColor3 = states[o.label] and library.Theme.Accent or library.Theme.Background
            fire()
        end)
        tickLabel.Text = states[o.label] and "x" or ""
        tick.BackgroundColor3 = states[o.label] and T.Accent or T.Background
    end
    function comp:GetStates() return states end
    function comp:SetState(label, v)
        if states[label] ~= nil then
            states[label] = v and true or false
            local b = boxes[label]
            if b then b.tick.Text = v and "x" or "" b.box.BackgroundColor3 = v and library.Theme.Accent or library.Theme.Background end
            fire()
        end
    end
    comp.__getValue = function() return states end
    library:_register(self.name .. "::" .. (opts.text or "Checkboxes"), function() return states end, function(t)
        for k, v in pairs(t) do if states[k] ~= nil then states[k] = v end end
        refresh() cb(states)
    end)
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        header.TextColor3 = library.Theme.Text
        fStroke.Color = library.Theme.Border
        for _, b in pairs(boxes) do b.lbl.TextColor3 = library.Theme.Text end
        refresh()
    end)
    comp._ghostApply = {frame, fStroke, header}
    return comp
end

function Tab:NewColorPicker(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 32)
    container.ClipsDescendants = true
    local T = library.Theme
    local color = opts.default or Color3.fromRGB(255, 0, 0)
    local h, s, v = Color3.toHSV(color)

    local header = new("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.ComponentBackground, Text = "", AutoButtonColor = false, Parent = container})
    corner(header, 6)
    local fStroke = stroke(header, T.Border, 1, 0)
    local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -50, 1, 0), Font = Enum.Font.Gotham, Text = opts.text or "Color", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
    local preview = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 26, 0, 18), BackgroundColor3 = color, Parent = header})
    corner(preview, 4)
    stroke(preview, T.Border, 1, 0)

    local panel = new("Frame", {Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = T.Background, Parent = container})
    corner(panel, 6)
    local svBox = new("ImageLabel", {Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -50, 0, 100), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Image = "", Parent = panel})
    corner(svBox, 4)
    local satGrad = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = svBox})
    corner(satGrad, 4)
    new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}), Parent = satGrad})
    local valGrad = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Parent = svBox})
    corner(valGrad, 4)
    new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}), Parent = valGrad})
    local svDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = svBox})
    corner(svDot, 4)
    stroke(svDot, Color3.fromRGB(0, 0, 0), 1, 0)

    local hueBar = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.new(0, 18, 0, 100), Parent = panel})
    corner(hueBar, 4)
    new("UIGradient", {Rotation = 90, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
    }), Parent = hueBar})
    local hueDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, h, 0), Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = hueBar})

    local cb = wrapCallback(self, opts.text or "Color", "ColorPicker", opts.callback)
    local function apply(silent)
        color = Color3.fromHSV(h, s, v)
        preview.BackgroundColor3 = color
        svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svDot.Position = UDim2.new(s, 0, 1 - v, 0)
        hueDot.Position = UDim2.new(0.5, 0, h, 0)
        comp:_fireChange(color)
        if not silent then cb(color) end
    end

    local open = false
    local function setOpen(o)
        open = o
        if open then
            comp._height = 32 + 116
            panel.Size = UDim2.new(1, 0, 0, 116)
            container.Size = UDim2.new(1, 0, 0, comp._height)
        else
            comp._height = 32
            panel.Size = UDim2.new(1, 0, 0, 0)
            container.Size = UDim2.new(1, 0, 0, 30)
        end
    end
    header.MouseButton1Click:Connect(function() setOpen(not open) end)

    local svDrag, hueDrag = false, false
    svBox.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then svDrag = true end end)
    hueBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then hueDrag = true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then svDrag = false hueDrag = false end end)
    UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if svDrag then
            s = math.clamp((i.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
            v = 1 - math.clamp((i.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
            apply()
        elseif hueDrag then
            h = math.clamp((i.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
            apply()
        end
    end)
    UserInputService.InputBegan:Connect(function(i)
        if open and i.UserInputType == Enum.UserInputType.MouseButton1 then
            local m = i.Position
            local p, sz = container.AbsolutePosition, container.AbsoluteSize
            if m.X < p.X or m.X > p.X + sz.X or m.Y < p.Y or m.Y > p.Y + sz.Y then
                setOpen(false)
            end
        end
    end)

    function comp:SetColor(c) color = c h, s, v = Color3.toHSV(c) apply() end
    function comp:GetColor() return color end
    comp.__getValue = function() return color end
    library:_register(self.name .. "::" .. (opts.text or "Color"), function() return color end, function(c) color = c h, s, v = Color3.toHSV(c) apply() cb(color) end)
    library:_onTheme(function()
        header.BackgroundColor3 = library.Theme.ComponentBackground
        label.TextColor3 = library.Theme.Text
        panel.BackgroundColor3 = library.Theme.Background
        fStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {header, fStroke, label}
    apply(true)
    return comp
end

function Tab:NewSection(opts)
    opts = opts or {}
    local comp, container = makeRow(self, 30, true)
    local T = library.Theme
    local frame = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.ComponentBackground, Parent = container})
    corner(frame, 6)
    local fStroke = stroke(frame, T.Border, 1, 0)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame})
    local header = new("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 0, Parent = frame})
    local arrow = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0, 16, 1, 0), Font = Enum.Font.GothamSemibold, Text = "v", TextColor3 = T.Accent, TextSize = 12, Parent = header})
    local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 28, 0, 0), Size = UDim2.new(1, -36, 1, 0), Font = Enum.Font.GothamSemibold, Text = opts.text or "Section", TextColor3 = T.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})

    local inner = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 1, Parent = frame})
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = inner})
    new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = inner})

    local innerTab = setmetatable({}, Tab)
    innerTab.name = self.name .. "/" .. (opts.text or "Section")
    innerTab.window = self.window
    innerTab.page = inner
    innerTab.components = {}

    local collapsed = opts.collapsed and true or false
    local function refresh()
        if collapsed then
            inner.Visible = false
            inner.AutomaticSize = Enum.AutomaticSize.None
            inner.Size = UDim2.new(1, 0, 0, 0)
            arrow.Text = ">"
        else
            inner.Visible = true
            inner.AutomaticSize = Enum.AutomaticSize.Y
            arrow.Text = "v"
        end
    end
    refresh()
    function comp:GetContainer() return innerTab end
    function comp:Collapse() collapsed = true refresh() end
    function comp:Expand() collapsed = false refresh() end
    function comp:Toggle() collapsed = not collapsed refresh() end
    header.MouseButton1Click:Connect(function() comp:Toggle() end)
    library:_onTheme(function()
        frame.BackgroundColor3 = library.Theme.ComponentBackground
        title.TextColor3 = library.Theme.Text
        arrow.TextColor3 = library.Theme.Accent
        fStroke.Color = library.Theme.Border
    end)
    comp._ghostApply = {frame, fStroke, title, arrow}
    return comp
end

function buildConfigTab(window)
    library._suppressRegister = true
    local tab = window:NewTab("Config")
    local nameBox = tab:NewTextBox({text = "Config Name", placeholder = "default"})
    local dd = tab:NewDropdown({text = "Saved Configs", options = {"(none)"}})
    local function refreshList()
        local list = library:ListConfigs()
        if #list == 0 then list = {"(none)"} end
        dd:SetOptions(list)
    end
    refreshList()
    tab:NewButton({text = "Save Config", callback = function()
        local n = nameBox:GetValue()
        if n == "" then n = "default" end
        library:SaveConfig(n)
        refreshList()
        library:Notify({title = "Config", text = "Saved '" .. n .. "'", duration = 2})
    end})
    tab:NewButton({text = "Load Config", callback = function()
        local n = dd:GetSelected()
        if n and n ~= "(none)" then
            library:LoadConfig(n)
            library:Notify({title = "Config", text = "Loaded '" .. n .. "'", duration = 2})
        end
    end})
    tab:NewButton({text = "Delete Config", callback = function()
        local n = dd:GetSelected()
        if n and n ~= "(none)" then
            library:DeleteConfig(n)
            refreshList()
            library:Notify({title = "Config", text = "Deleted '" .. n .. "'", duration = 2})
        end
    end})
    tab:NewButton({text = "Export to Clipboard", callback = function()
        local n = dd:GetSelected()
        if n == "(none)" then n = nil end
        clip(library:ExportConfig(n))
        library:Notify({title = "Config", text = "Exported to clipboard", duration = 2})
    end})
    local importBox = tab:NewTextBox({text = "Import JSON", placeholder = "paste config..."})
    tab:NewButton({text = "Import Config", callback = function()
        if library:ImportConfig(importBox:GetValue()) then
            library:Notify({title = "Config", text = "Imported", duration = 2})
        else
            library:Notify({title = "Config", text = "Invalid JSON", duration = 2})
        end
    end})
    tab:NewSeparator()
    tab:NewButton({text = "Open Theme Editor", callback = function() library:OpenThemeEditor() end})
    tab:NewButton({text = "Show Activity Log", callback = function() window:ShowLog() end})
    library._suppressRegister = false
    return tab
end

local ACTION_COLORS = {
    Toggle = Color3.fromRGB(90, 150, 255),
    Slider = Color3.fromRGB(240, 220, 90),
    Button = Color3.fromRGB(100, 220, 120),
    Dropdown = Color3.fromRGB(180, 120, 255),
    MultiDropdown = Color3.fromRGB(180, 120, 255),
}

function buildLogTab(window)
    library._suppressRegister = true
    local tab = window:NewTab("Log")
    tab.button.Visible = false
    tab:NewButton({text = "Copy Log", callback = function()
        clip(library:ExportLog())
        library:Notify({title = "Log", text = "Copied to clipboard", duration = 2})
    end})
    tab:NewButton({text = "Clear Log", callback = function() library:ClearLog() end})

    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 999,
        Parent = tab.page,
    })
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = holder})

    local function render()
        for _, c in ipairs(holder:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for i, e in ipairs(library._activityLog) do
            local row = new("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = library.Theme.ComponentBackground, LayoutOrder = i, Parent = holder})
            corner(row, 4)
            local accentCol = ACTION_COLORS[e.action] or library.Theme.SubText
            new("Frame", {BackgroundColor3 = accentCol, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Parent = row})
            local valStr = e.value
            if typeof(valStr) == "Color3" then
                valStr = string.format("(%d,%d,%d)", valStr.R * 255, valStr.G * 255, valStr.B * 255)
            elseif type(valStr) == "table" then
                local parts = {}
                for k, v in pairs(valStr) do table.insert(parts, tostring(k) .. (type(v) == "boolean" and ("=" .. tostring(v)) or "")) end
                valStr = table.concat(parts, ",")
            else
                valStr = tostring(valStr)
            end
            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -12, 1, 0),
                Font = Enum.Font.Gotham,
                Text = string.format("[%.1fs] %s | %s | %s | %s", e.elapsed, e.tab, e.component, e.action, valStr),
                TextColor3 = library.Theme.Text,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
        end
    end
    table.insert(library._logListeners, function() render() end)
    render()
    library._suppressRegister = false
    return tab
end

function Window:ShowLog()
    if self._logTab then
        self._logTab.button.Visible = true
        self._logTab:Open()
    end
end

function Window:EnableSearch()
    if self._searchEnabled then return end
    self._searchEnabled = true
    local sh = 32
    self.searchHolder.Size = UDim2.new(1, 0, 0, sh)
    self.searchHolder.Visible = true
    self.tabBarHolder.Position = UDim2.new(0, 0, 0, 36 + sh)
    self.contentHolder.Position = UDim2.new(0, 0, 0, 66 + sh)
    self.contentHolder.Size = UDim2.new(1, 0, 1, -(66 + sh))

    library._suppressRegister = true
    local resultsTab = self:NewTab("Search")
    resultsTab.button.Visible = false
    library._suppressRegister = false
    self._resultsTab = resultsTab

    local moved = {}
    local prevTab = nil

    local function labelOf(container)
        for _, d in ipairs(container:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Text ~= "v" and d.Text ~= "^" then
                return d.Text
            end
        end
        return ""
    end

    local function restoreAll()
        for container, parent in pairs(moved) do
            if container and container.Parent then
                container.Parent = parent
            end
        end
        moved = {}
    end

    self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = self.searchBox.Text:lower()
        if q == "" then
            restoreAll()
            resultsTab:Hide()
            if prevTab then prevTab:Open() end
            return
        end
        if self._activeTab ~= resultsTab then
            prevTab = self._activeTab
        end
        for _, entry in ipairs(self._searchIndex) do
            local container = entry.container
            if container and container.Parent then
                local lbl = labelOf(container):lower()
                local match = lbl:find(q, 1, true) ~= nil
                if match then
                    if not moved[container] then
                        moved[container] = container.Parent
                        container.Parent = resultsTab.page
                    end
                else
                    if moved[container] then
                        container.Parent = moved[container]
                        moved[container] = nil
                    end
                end
            end
        end
        resultsTab:Open()
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            self.searchBox:CaptureFocus()
        end
    end)
end

function Window:SetGhostMode(state)
    self._ghost = state and true or false
    local main = self.main
    if self._ghost then
        self._ghostStore = {}
        for _, d in ipairs(main:GetDescendants()) do
            local store = {}
            if d:IsA("GuiObject") then
                if d.BackgroundTransparency < 1 then store.BackgroundTransparency = d.BackgroundTransparency end
            end
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                store.TextTransparency = d.TextTransparency
            end
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                store.ImageTransparency = d.ImageTransparency
            end
            if d:IsA("UIStroke") then
                store.Transparency = d.Transparency
            end
            if next(store) then
                self._ghostStore[d] = store
                local goal = {}
                for k in pairs(store) do goal[k] = 1 end
                tween(d, TWEEN_SLOW, goal)
            end
        end
        if self._ghostStore[main] == nil then self._ghostStore[main] = {BackgroundTransparency = main.BackgroundTransparency} end
        tween(main, TWEEN_SLOW, {BackgroundTransparency = 1})
        if self.mainStroke then
            self.mainStroke.Transparency = 0.85
            self.mainStroke.Color = Color3.fromRGB(255, 255, 255)
        end
        tween(self.ghostDot, TWEEN_SLOW, {TextTransparency = 0.3})
    else
        for d, store in pairs(self._ghostStore) do
            if d and d.Parent then
                tween(d, TWEEN_SLOW, store)
            end
        end
        self._ghostStore = {}
        if self.mainStroke then
            self.mainStroke.Transparency = 1
            self.mainStroke.Color = library.Theme.Border
        end
        tween(self.ghostDot, TWEEN_SLOW, {TextTransparency = 1})
    end
end

function Window:ToggleGhostMode() self:SetGhostMode(not self._ghost) end

function Window:SetGhostKey(key)
    self._ghostKey = key
    if self._ghostConn then self._ghostConn:Disconnect() end
    self._ghostConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == self._ghostKey then
            self:ToggleGhostMode()
        end
    end)
end

local THEME_ORDER = {"Background", "TopBar", "Accent", "Text", "SubText", "ComponentBackground", "Border", "ToggleON", "ToggleOFF"}

local THEME_PRESETS = {
    Dark = THEME_DEFAULTS,
    Light = {
        Background = Color3.fromRGB(235, 235, 240),
        TopBar = Color3.fromRGB(220, 220, 228),
        Accent = Color3.fromRGB(110, 70, 230),
        Text = Color3.fromRGB(30, 30, 35),
        SubText = Color3.fromRGB(90, 90, 100),
        ComponentBackground = Color3.fromRGB(210, 210, 218),
        Border = Color3.fromRGB(180, 180, 190),
        ToggleON = Color3.fromRGB(110, 70, 230),
        ToggleOFF = Color3.fromRGB(160, 160, 170),
    },
    Red = {
        Background = Color3.fromRGB(28, 18, 20),
        TopBar = Color3.fromRGB(22, 14, 16),
        Accent = Color3.fromRGB(235, 60, 70),
        Text = Color3.fromRGB(240, 230, 232),
        SubText = Color3.fromRGB(160, 130, 135),
        ComponentBackground = Color3.fromRGB(42, 28, 30),
        Border = Color3.fromRGB(70, 40, 44),
        ToggleON = Color3.fromRGB(235, 60, 70),
        ToggleOFF = Color3.fromRGB(80, 55, 58),
    },
    Dracula = {
        Background = Color3.fromRGB(40, 42, 54),
        TopBar = Color3.fromRGB(33, 34, 44),
        Accent = Color3.fromRGB(189, 147, 249),
        Text = Color3.fromRGB(248, 248, 242),
        SubText = Color3.fromRGB(150, 152, 170),
        ComponentBackground = Color3.fromRGB(52, 54, 70),
        Border = Color3.fromRGB(68, 71, 90),
        ToggleON = Color3.fromRGB(189, 147, 249),
        ToggleOFF = Color3.fromRGB(80, 82, 100),
    },
    Ocean = {
        Background = Color3.fromRGB(18, 28, 38),
        TopBar = Color3.fromRGB(14, 22, 30),
        Accent = Color3.fromRGB(70, 190, 230),
        Text = Color3.fromRGB(225, 238, 245),
        SubText = Color3.fromRGB(130, 160, 175),
        ComponentBackground = Color3.fromRGB(28, 42, 56),
        Border = Color3.fromRGB(45, 65, 82),
        ToggleON = Color3.fromRGB(70, 190, 230),
        ToggleOFF = Color3.fromRGB(55, 75, 92),
    },
}

function library:ExportTheme()
    local lines = {"{"}
    for _, k in ipairs(THEME_ORDER) do
        local c = self.Theme[k]
        table.insert(lines, string.format("  %s = Color3.fromRGB(%d, %d, %d),", k, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)))
    end
    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

function library:ImportTheme(str)
    if type(str) ~= "string" or not loadstring then return false end
    local fn = loadstring("return " .. str)
    if not fn then return false end
    local ok, tbl = pcall(fn)
    if ok and type(tbl) == "table" then
        for k, v in pairs(tbl) do
            if self.Theme[k] ~= nil and typeof(v) == "Color3" then
                self.Theme[k] = v
            end
        end
        applyTheme()
        return true
    end
    return false
end

function library:SetTheme(key, color)
    if self.Theme[key] ~= nil then
        self.Theme[key] = color
        applyTheme()
    end
end

function library:OpenThemeEditor()
    if self._themeEditor and self._themeEditor.gui and self._themeEditor.gui.Parent then
        self._themeEditor._visible = true
        self._themeEditor.main.Visible = true
        return self._themeEditor
    end
    local win = self:CreateWindow({title = "Theme Editor", noExtraTabs = true})
    win.main.Size = UDim2.new(0, 340, 0, 360)
    win.main.Position = UDim2.new(0.5, 280, 0.5, 0)
    self._themeEditor = win

    library._suppressRegister = true
    local tab = win:NewTab("Colors")
    local cps = {}
    for _, key in ipairs(THEME_ORDER) do
        cps[key] = tab:NewColorPicker({
            text = key,
            default = self.Theme[key],
            callback = function(c)
                self.Theme[key] = c
                applyTheme()
            end,
        })
    end

    local presetTab = win:NewTab("Presets")
    local function applyPreset(name)
        local p = THEME_PRESETS[name]
        if not p then return end
        for k, v in pairs(p) do
            if self.Theme[k] ~= nil then self.Theme[k] = v end
        end
        applyTheme()
        for k, cp in pairs(cps) do
            if self.Theme[k] then cp:SetColor(self.Theme[k]) end
        end
        self:Notify({title = "Theme", text = name .. " applied", duration = 2})
    end
    for _, name in ipairs({"Dark", "Light", "Red", "Dracula", "Ocean"}) do
        presetTab:NewButton({text = name, callback = function() applyPreset(name) end})
    end
    presetTab:NewSeparator()
    presetTab:NewButton({text = "Export Theme (clipboard)", callback = function()
        clip(self:ExportTheme())
        self:Notify({title = "Theme", text = "Exported to clipboard", duration = 2})
    end})
    local importBox = presetTab:NewTextBox({text = "Import Theme", placeholder = "paste theme table..."})
    presetTab:NewButton({text = "Import Theme", callback = function()
        if self:ImportTheme(importBox:GetValue()) then
            for k, cp in pairs(cps) do
                if self.Theme[k] then cp:SetColor(self.Theme[k]) end
            end
            self:Notify({title = "Theme", text = "Imported", duration = 2})
        else
            self:Notify({title = "Theme", text = "Invalid theme", duration = 2})
        end
    end})
    library._suppressRegister = false
    tab:Open()
    return win
end

return library
