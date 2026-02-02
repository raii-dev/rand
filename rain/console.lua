local Console = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local messages = {}

local maxMessages = 10
local messageHeight = 18
local messageLifetime = 4

local screenGui
local holder

-----------------------------------------------------------
-- FONTS
-----------------------------------------------------------

writefile("ffff.ttf", game:HttpGet(
    "https://github.com/ericoporto/pixel-utf8-fonts/blob/ac77809f15700d869eb22da1d3422262970cd6f6/unifont/unifont-14.0.04.ttf"
))

local fontJson = {
    name = "SmallestPixel7",
    faces = {
        {
            name = "Regular",
            weight = 400,
            style = "normal",
            assetId = getcustomasset("ffff.ttf")
        }
    }
}

writefile("dddd.ttf", HttpService:JSONEncode(fontJson))

-----------------------------------------------------------
-- INIT UI
-----------------------------------------------------------

function Console.Init()
    if screenGui then return end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RaiiConsole"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = (gethui and gethui()) or cloneref(game:GetService("CoreGui"))

    holder = Instance.new("Frame")
    holder.Name = "MessageHolder"
    holder.Size = UDim2.new(0, 600, 0, maxMessages * messageHeight)
    holder.Position = UDim2.new(0, 20, 0, 260)
    holder.BackgroundTransparency = 1
    holder.ClipsDescendants = true
    holder.Parent = screenGui

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 0)
    layout.Parent = holder
end

-----------------------------------------------------------
-- CREATE MESSAGE ELEMENT
-----------------------------------------------------------

function Console._createMessage(text)
    -- OUTER FRAME (VERTICAL POSITION — DO NOT TOUCH X)
    local wrapper = Instance.new("Frame")
    wrapper.Size = UDim2.new(1, 0, 0, messageHeight)
    wrapper.BackgroundTransparency = 1
    wrapper.Parent = holder

    -- INNER FRAME (ANIMATE THIS ONLY)
    local slide = Instance.new("Frame")
    slide.Size = UDim2.new(1, 0, 1, 0)
    slide.Position = UDim2.new(-1, 0, 0, 0) -- start offscreen
    slide.BackgroundTransparency = 1
    slide.Parent = wrapper

    local prefix = Instance.new("TextLabel")
    prefix.BackgroundTransparency = 1
    prefix.Size = UDim2.new(0, 70, 1, 0)
    prefix.FontFace = Font.new(getcustomasset("dddd.ttf"))
    prefix.TextSize = 14
    prefix.TextColor3 = Color3.fromRGB(139, 169, 214)
    prefix.Text = "[Rain]"
    prefix.TextXAlignment = Enum.TextXAlignment.Left
    prefix.TextStrokeTransparency = 0.5
    prefix.TextStrokeColor3 = Color3.new(0, 0, 0)
    prefix.Parent = slide

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, -70, 1, 0)
    body.Position = UDim2.new(0, 32, 0, 0)
    body.FontFace = Font.new(getcustomasset("dddd.ttf"))
    body.TextSize = 14
    body.TextColor3 = Color3.new(1, 1, 1)
    body.TextStrokeTransparency = 0.5
    body.TextStrokeColor3 = Color3.new(0, 0, 0)
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.RichText = true
    body.Text = text
    body.Parent = slide

    return wrapper, slide, body
end

-----------------------------------------------------------
-- ADD MESSAGE
-----------------------------------------------------------

function Console.AddMessage(text)
    if not holder then Console.Init() end

    local wrapper, slide, body = Console._createMessage(text)
    table.insert(messages, 1, wrapper)

    -------------------------------------------------
    -- SLIDE IN (only move the slide frame)
    -------------------------------------------------
    TweenService:Create(
        slide,
        TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, 0) }
    ):Play()

    -------------------------------------------------
    -- COUNTDOWN
    -------------------------------------------------
    local startTime = tick()
    task.spawn(function()
        while wrapper.Parent do
            local elapsed = tick() - startTime
            local remaining = math.max(0, messageLifetime - elapsed)
            body.Text = string.format("[%.1fs] %s", remaining, text)
            if remaining <= 0 then break end
            task.wait(0.1)
        end
    end)

    -------------------------------------------------
    -- REMOVE MESSAGE (slide out left)
    -------------------------------------------------
    task.delay(messageLifetime, function()
        TweenService:Create(
            slide,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad),
            { Position = UDim2.new(-1, 0, 0, 0) }
        ):Play()

        task.wait(0.25)
        wrapper:Destroy()
        table.remove(messages, table.find(messages, wrapper))
    end)

    -------------------------------------------------
    -- REMOVE EXTRA MESSAGES
    -------------------------------------------------
    while #messages > maxMessages do
        local old = messages[#messages]
        table.remove(messages, #messages)

        local oldSlide = old:FindFirstChildOfClass("Frame")

        TweenService:Create(
            oldSlide,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad),
            { Position = UDim2.new(-1, 0, 0, 0) }
        ):Play()

        task.wait(0.25)
        old:Destroy()
    end
end

return Console
