local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Camera = Workspace.CurrentCamera

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESP_GUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = cloneref(game:GetService("CoreGui"))

local ESP = {
    Categories = {}, -- options 
    Objects = {},    -- object {Model, Category, NameLabel, DistLabel, Connection}
}

local function createLabel(color)
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromOffset(200, 18)
    label.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold)
    label.TextSize = 10
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.Visible = false
    label.Parent = screenGui
    return label
end

function ESP:SetCategory(category, options)
    self.Categories[category] = {
        Enabled = options.Enabled ~= false,
        ShowNames = options.ShowNames ~= false,
        ShowDistance = options.ShowDistance ~= false,
        Distance = options.Distance or 10000,
        Color = options.Color or Color3.fromRGB(255, 255, 255),
        DistanceColor = options.DistanceColor or Color3.fromRGB(100, 100, 100),
        Validator = options.Validator
    }
end

function ESP:Add(object, category, group)
    if not (object:IsA("Model") or object:IsA("CFrameValue") or object:IsA("BasePart")) then return end
    if self.Objects[object] then return end

    local function tryAdd()
        local cat = ESP.Categories[category]
        if not cat then return false end

        local position
        if object:IsA("Model") then
            local root = object.PrimaryPart or object:FindFirstChild("HumanoidRootPart") or object:FindFirstChildWhichIsA("BasePart")
            if not root then return false end
            position = function() return root.Position end
        elseif object:IsA("CFrameValue") then
            position = function() return object.Value.Position end
        elseif object:IsA("BasePart") then
            position = function() return object.Position end
        end

        local nameLabel = createLabel(cat.Color)
        local distLabel = createLabel(Color3.fromRGB(200, 200, 200))

        local obj = {
            Model = object,
            Category = category,
            NameLabel = nameLabel,
            CustomName = nil,
            Group = group or "Default",
            DistLabel = distLabel,
            GetPosition = position,
            Connection = object.AncestryChanged:Connect(function(_, parent)
                if not parent then ESP:Remove(object) end
            end)
        }

        ESP.Objects[object] = obj
        return true
    end

    if not tryAdd() and object:IsA("Model") then
        local conn
        conn = object:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
            if tryAdd() then conn:Disconnect() end
        end)
    end
end

function ESP:Remove(model)
    local obj = self.Objects[model]
    if obj then
        if obj.Connection then obj.Connection:Disconnect() end
        if obj.NameLabel then obj.NameLabel:Destroy() end
        if obj.DistLabel then obj.DistLabel:Destroy() end
        self.Objects[model] = nil
    end
end

function ESP:AddObjectListener(parent, category, useDescendants)
    local deep = useDescendants == true

    local function addModel(obj)
        if obj:IsA("Model") or obj:IsA("BasePart") then
            self:Add(obj, category)
        end
    end

    if deep then
        for _, descendant in ipairs(parent:GetDescendants()) do
            addModel(descendant)
        end

        parent.DescendantAdded:Connect(function(descendant)
            addModel(descendant)
        end)
    else
        for _, child in ipairs(parent:GetChildren()) do
            addModel(child)
        end

        parent.ChildAdded:Connect(function(child)
            addModel(child)
        end)
    end
end

function ESP:SetVisibleGroups(categoryName, groups)
    local cat = self.Categories[categoryName]
    if not cat then return end

    if not groups or #groups == 0 then
        cat.VisibleGroups = nil 
    else
        cat.VisibleGroups = groups
    end
end

function ESP:Unload()
    if self.RenderConnection then
        self.RenderConnection:Disconnect()
        self.RenderConnection = nil
    end

    for model, obj in pairs(self.Objects) do
        if obj.Connection then obj.Connection:Disconnect() end
        if obj.NameLabel then obj.NameLabel:Destroy() end
        if obj.DistLabel then obj.DistLabel:Destroy() end
    end
    self.Objects = {}
    self.Categories = {}

    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
end

RunService.RenderStepped:Connect(function()
    if Camera ~= workspace.CurrentCamera then
        Camera = workspace.CurrentCamera
    end

    local camPos = Camera.CFrame.Position

    for model, obj in pairs(ESP.Objects) do
        local catCfg = ESP.Categories[obj.Category]
        if not catCfg then continue end

        if not model:IsDescendantOf(game) then
            ESP:Remove(model)
            continue
        end

        local pos3D = obj.GetPosition and obj.GetPosition()
        if not pos3D then
            obj.NameLabel.Visible = false
            obj.DistLabel.Visible = false
            continue
        end

        local distance = (camPos - pos3D).Magnitude
        local valid = not catCfg.Validator or catCfg.Validator(model)

        local pos2D, onScreen = Camera:WorldToViewportPoint(pos3D)

        local groupValid = true
        if catCfg.VisibleGroups and #catCfg.VisibleGroups > 0 then
            groupValid = false
            for _, allowedGroup in ipairs(catCfg.VisibleGroups) do
                if obj.Group == allowedGroup then
                    groupValid = true
                    break
                end
            end
        end

        local visible = onScreen and catCfg.Enabled and valid and groupValid and distance <= catCfg.Distance

        if visible then
            local baseX, baseY = pos2D.X, pos2D.Y

            if catCfg.ShowNames then
                if obj.Category == "Corpses" or obj.Category == "Corpse" then
                    if obj.CustomName then
                        obj.NameLabel.Text = obj.CustomName .. "'s Corpse"
                    elseif model.Name then
                        obj.NameLabel.Text = model.Name .. "'s Corpse"
                    else
                        obj.NameLabel.Text = "Object's Corpse"
                    end
                else
                    obj.NameLabel.Text = obj.CustomName or (model.Name or "Object")
                end

                obj.NameLabel.Visible = true
                obj.NameLabel.TextColor3 = catCfg.Color or Color3.fromRGB(255, 255, 255)

                -- place name first
                obj.NameLabel.Position = UDim2.fromOffset(baseX, baseY)

                if catCfg.ShowDistance then
                    obj.DistLabel.Text = string.format("[%dm]", math.floor(distance))
                    obj.DistLabel.Visible = true
                    obj.DistLabel.TextColor3 = catCfg.DistanceColor or Color3.fromRGB(100, 100, 100)

                    -- place distance label *below* name label
                    obj.DistLabel.Position = UDim2.fromOffset(baseX, baseY + obj.NameLabel.AbsoluteSize.Y - 8)
                else
                    obj.DistLabel.Visible = false
                end
            else
                obj.NameLabel.Visible = false
                obj.DistLabel.Visible = false
            end
        else
            obj.NameLabel.Visible = false
            obj.DistLabel.Visible = false
        end
    end
end)

return ESP
