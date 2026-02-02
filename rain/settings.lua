return function(library, Settings, themes, window, modelESP, HttpService, lp)
    ---------------------------------------------------------------------------------------------------------
    -- [[ SETTINGS / THEMING ]] --
    ---------------------------------------------------------------------------------------------------------

    local RunService = game:GetService("RunService")

    -- Watermark
    local fps, frames = 0, 0
    RunService.RenderStepped:Connect(function() frames += 1 end)

    task.spawn(function()
        while task.wait(1) do
            fps, frames = frames, 0
        end
    end)

    local watermark = library:watermark({default = "Rain | " .. fps .. " FPS"})
    task.spawn(function()
        while task.wait(1) do
            watermark.change_text("Rain | " .. fps .. " FPS")
        end
    end)

    -- Theme / Configs Section
    local column = Settings:column()
    local holder, section = column:multi_section({names = {"Configs", "Themes"}})

    -------------------------------------------------------------------------------------------------
    -- // Theme Controls \\ --
    -------------------------------------------------------------------------------------------------

    section:label({name = "Accent"})
        :colorpicker({name = "Accent", color = themes.preset.accent, flag = "Accent", callback = function(color)
            library:update_theme("accent", color)
        end})

    section:label({name = "Contrast"})
        :colorpicker({name = "Low", color = themes.preset.low_contrast, flag = "low_contrast", callback = function(color)
            if (library.flags["high_contrast"] and library.flags["low_contrast"]) then
                library:update_theme("contrast", ColorSequence.new{
                    ColorSequenceKeypoint.new(0, library.flags["low_contrast"].Color),
                    ColorSequenceKeypoint.new(1, library.flags["high_contrast"].Color)
                })
            end
            library:update_theme("low_contrast", color)
        end})
        :colorpicker({name = "High", color = themes.preset.high_contrast, flag = "high_contrast", callback = function(color)
            if (library.flags["high_contrast"] and library.flags["low_contrast"]) then
                library:update_theme("contrast", ColorSequence.new{
                    ColorSequenceKeypoint.new(0, library.flags["low_contrast"].Color),
                    ColorSequenceKeypoint.new(1, library.flags["high_contrast"].Color)
                })
            end
            library:update_theme("high_contrast", color)
        end})

    section:label({name = "Inline"})
        :colorpicker({name = "Inline", color = themes.preset.inline, flag = "Inline", callback = function(color)
            library:update_theme("inline", color)
        end})

    section:label({name = "Outline"})
        :colorpicker({name = "Outline", color = themes.preset.outline, flag = "Outline", callback = function(color)
            library:update_theme("outline", color)
        end})

    section:label({name = "Text Color"})
        :colorpicker({name = "Main", color = themes.preset.text, flag = "Main", callback = function(color)
            library:update_theme("text", color)
        end})
        :colorpicker({name = "Outline", color = themes.preset.text_outline, flag = "Outline", callback = function(color)
            library:update_theme("text_outline", color)
        end})

    section:label({name = "Glow"})
        :colorpicker({name = "Glow", color = themes.preset.glow, callback = function(color)
            library:update_theme("glow", color)
        end})

    -------------------------------------------------------------------------------------------------
    -- // Config Controls \\ --
    -------------------------------------------------------------------------------------------------

    local items = holder.items

    getgenv().load_config = function(name)
        library:load_config(readfile(library.directory .. "/configs/" .. name .. ".cfg"))
    end 

    local section = holder:section({name = "Options"})
    local config_holder = holder:list({flag = "config_name_list", size = 130})

    holder:textbox({flag = "config_name_text_box"})

    holder:button_holder({})
    holder:button({name = "Create", callback = function()
        writefile(library.directory .. "/configs/" .. library.flags["config_name_text_box"] .. ".cfg", library:get_config())
        library:config_list_update(config_holder)
    end})
    holder:button({name = "Delete", callback = function()
        delfile(library.directory .. "/configs/" .. library.flags["config_name_list"] .. ".cfg")
        library:config_list_update(config_holder)
    end})

    holder:button_holder({})
    holder:button({name = "Load", callback = function()
        library:load_config(readfile(library.directory .. "/configs/" .. library.flags["config_name_list"] .. ".cfg"))
        library:notification({text = "Loaded Config: " .. library.flags["config_name_list"], time = 3})
    end})
    holder:button({name = "Save", callback = function()
        writefile(library.directory .. "/configs/" .. library.flags["config_name_list"] .. ".cfg", library:get_config())
        library:config_list_update(config_holder)
        library:notification({text = "Saved Config: " .. library.flags["config_name_list"], time = 3})
    end})

    holder:button_holder({})
    holder:button({name = "Refresh Configs", callback = function()
        library:config_list_update(config_holder)
    end})
    library:config_list_update(config_holder)

    holder:button_holder({})
    holder:button({name = "Unload Config", callback = function()
        library:load_config(library.old_config)
    end})
    holder:button({name = "Unload Menu", callback = function()
        library:load_config(library.old_config)
        for _, gui in library.guis do gui:Destroy() end 
        for _, connection in library.connections do connection:Disconnect() end
        modelESP:Unload()
    end})

    -------------------------------------------------------------------------------------------------
    -- [[ OTHER SETTINGS ]] --
    -------------------------------------------------------------------------------------------------

    local other_section = column:section({name = "Other"})

    -- Keybinds & toggles
    local bind_label = other_section:label({name = "UI Bind"})
    bind_label:keybind({
        callback = function()
            window.set_menu_visibility(not window.opened)
        end,
        key = Enum.KeyCode.LeftAlt
    })

    other_section:toggle({
        name = "Keybind List",
        flag = "keybind_list",
        callback = function(bool)
            library.keybind_list_frame.Visible = bool
        end
    })

    other_section:toggle({
        name = "Watermark",
        flag = "watermark",
        callback = function(bool)
            watermark.set_visible(bool)
        end
    })

    -- Clipboard row
    other_section:button_holder({})
    other_section:button({name = "Copy JobId", callback = function() setclipboard(game.JobId) end})
    other_section:button({name = "Copy GameID", callback = function() setclipboard(game.GameId) end})
    other_section:button({name = "Copy Join Script", callback = function()
        setclipboard(('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game.Players.LocalPlayer)'):format(
            game.PlaceId, game.JobId
        ))
    end})

    -- Server actions row
    other_section:button_holder({})
    other_section:button({name = "Rejoin", callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
    end})
    other_section:button({name = "Join New Server", callback = function()
        local apiRequest = HttpService:JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        local data = apiRequest.data[random(1, #apiRequest.data)]
        if data and data.playing <= library.config_flags["max_players"] then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, data.id)
        end
    end})

    library:config_list_update()

    for index, value in themes.preset do
        pcall(function()
            library:update_theme(index, value)
        end)
    end

    task.wait()
    library.old_config = library:get_config()
end
