local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Visuals = {}

local function createDrawing(typeStr, props)
    local obj = Drawing.new(typeStr)
    for k,v in pairs(props or {}) do
        obj[k] = v
    end
    return obj
end

-- ================== FOV Circle ==================
function Visuals.newFOV(config)
    config = config or {}
    local radius = config.Radius or 100
    local outlineThickness = 3
    local sides = config.Sides or 64
    local color = config.Color or Color3.fromRGB(255,255,255)
    local center = config.Center or false
    local visible = true

    local outline = createDrawing("Circle", {
        Radius = radius,
        NumSides = sides,
        Color = Color3.fromRGB(0,0,0),
        Thickness = outlineThickness,
        Filled = false,
        Transparency = 1,
        Visible = config.Outline or false,
    })

    local circle = createDrawing("Circle", {
        Radius = radius,
        NumSides = sides,
        Color = color,
        Thickness = 1,
        Filled = false,
        Transparency = 1,
        Visible = true,
    })

    local obj = {
        _circle = circle,
        _outline = outline,
        _center = center,
        _outlineFlag = config.Outline or false,
        _visible = true,
        _sides = sides
    }

    obj._conn = RunService.RenderStepped:Connect(function()
        local pos = center and Workspace.CurrentCamera.ViewportSize/2 or UserInputService:GetMouseLocation()
        outline.Position = pos
        circle.Position = pos
        outline.NumSides = obj._sides
        circle.NumSides = obj._sides
    end)

    function obj:SetRadius(r)
        circle.Radius = r
        outline.Radius = r
    end

    function obj:SetSides(n)
        obj._sides = n
    end

    function obj:SetColor(c)
        circle.Color = c
    end

    function obj:SetCenter(state)
        self._center = state
    end

    function obj:SetOutline(state)
        self._outlineFlag = state
        outline.Visible = state and self._visible
    end

    function obj:SetVisibility(state)
        self._visible = state
        circle.Visible = state
        outline.Visible = state and self._outlineFlag
    end

    function obj:Remove()
        circle:Remove()
        outline:Remove()
        if self._conn then self._conn:Disconnect() end
    end

    return obj
end

-- ================== Crosshair ==================
function Visuals.newCrosshair(config)
    config = config or {}
    local numLines = 4
    local length = config.Length or 10
    local color = config.Color or Color3.fromRGB(255,255,255)
    local center = config.Center or false
    local visible = true

    local lines, outlines = {}, {}

    for i=1,numLines do
        outlines[i] = createDrawing("Line", {
            Color = Color3.fromRGB(0,0,0),
            Thickness = 3,
            Transparency = 1,
            Visible = config.Outline or false,
        })
    end

    for i=1,numLines do
        lines[i] = createDrawing("Line", {
            Color = color,
            Thickness = 1,
            Transparency = 1,
            Visible = true,
        })
    end

    local function round(v) return Vector2.new(math.floor(v.X+0.5), math.floor(v.Y+0.5)) end

    local obj = {}
    obj._conn = RunService.RenderStepped:Connect(function()
        local pos = center and Workspace.CurrentCamera.ViewportSize/2 or UserInputService:GetMouseLocation()
        local offsets = { Vector2.new(0,-length), Vector2.new(0,length), Vector2.new(-length,0), Vector2.new(length,0) }

        for i=1,numLines do
            local startPos = round(pos)
            local endPos   = round(pos + offsets[i])

            local dir = (endPos - startPos).Unit
            local extension = 2
            local outlineEnd = endPos + dir * extension

            outlines[i].From, outlines[i].To = startPos, outlineEnd
            lines[i].From, lines[i].To = startPos, endPos
        end
    end)

    function obj:SetLength(l) length = l end
    function obj:SetColor(c)
        color = c
        for _,l in ipairs(lines) do l.Color = c end
    end
    function obj:SetCenter(state) center = state end
    function obj:SetOutline(state)
        for _,o in ipairs(outlines) do o.Visible = state and visible end
    end
    function obj:SetVisibility(state)
        visible = state
        for _,l in ipairs(lines) do l.Visible = state end
        for _,o in ipairs(outlines) do o.Visible = state and config.Outline end
    end
    function obj:Remove()
        for _,l in ipairs(lines) do l:Remove() end
        for _,o in ipairs(outlines) do o:Remove() end
        if obj._conn then obj._conn:Disconnect() end
    end

    return obj
end

-- ================== Snapline ==================
function Visuals.newSnapline(config)
    config = config or {}
    local localPlayer = Players.LocalPlayer
    local useCenter = config.Center or false
    local visible = true
    local library = config.Library
    local maxDistanceOverride, fovRadiusOverride = nil, nil

    local outline = createDrawing("Line", {
        Color = Color3.fromRGB(0,0,0),
        Thickness = (config.Thickness or 2) + 2,
        Transparency = 1,
        Visible = config.Outline or false,
    })

    local line = createDrawing("Line", {
        Color = config.Color or Color3.fromRGB(255,255,255),
        Thickness = config.Thickness or 2,
        Transparency = 1,
        Visible = true,
    })

    local conn = RunService.RenderStepped:Connect(function()
        if not visible then return end
        local startPos = useCenter and Workspace.CurrentCamera.ViewportSize/2 or UserInputService:GetMouseLocation()
        local maxDistance = maxDistanceOverride or (library and library.flags['Max_Distance']) or math.huge
        local fovRadius = fovRadiusOverride or (library and library.flags['FOVRadius']) or math.huge

        local closestPos
        local closestDist = math.huge
        local camera = Workspace.CurrentCamera

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer and player.Character and (player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HeadCollider") or player.Character:FindFirstChild("HumanoidRootPart")) then
                local head = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HeadCollider") or player.Character:FindFirstChild("HumanoidRootPart")
                local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                    local distScreen = (startPos - screenVec).Magnitude
                    local distWorld = (camera.CFrame.Position - head.Position).Magnitude
                    if distScreen <= fovRadius and distWorld <= maxDistance and distScreen < closestDist then
                        closestDist = distScreen
                        closestPos = screenVec
                    end
                end
            end
        end

       if closestPos then
            local dir = (closestPos - startPos).Unit
            local extension = 2 
            local outlineEnd = closestPos + dir * extension

            outline.From, outline.To = startPos, outlineEnd
            outline.Visible = config.Outline or false

            line.From, line.To = startPos, closestPos
            line.Visible = true
        else
            outline.Visible = false
            line.Visible = false
        end
    end)

    local obj = {}
    function obj:SetMaxDistance(value) maxDistanceOverride = value end
    function obj:SetFOVRadius(value) fovRadiusOverride = value end
    function obj:SetCenter(state) useCenter = state end
    function obj:SetColor(c) line.Color = c end
    function obj:SetOutline(state) outline.Visible = state and visible end
    function obj:SetThickness(t)
        line.Thickness = t
        outline.Thickness = t + 2
    end
    function obj:SetVisibility(state)
        visible = state
        line.Visible = state
        outline.Visible = state and config.Outline
    end
    function obj:Remove()
        line:Remove()
        outline:Remove()
        if conn then conn:Disconnect() end
    end

    return obj
end

return Visuals
