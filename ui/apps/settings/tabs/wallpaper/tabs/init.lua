-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2025 Kasper24
-------------------------------------------
local gtable = require("gears.table")
local wibox = require("wibox")
local widgets = require("ui.widgets")
local beautiful = require("beautiful")
local theme_daemon = require("daemons.system.theme")
local library = require("library")
local dpi = beautiful.xresources.apply_dpi
local setmetatable = setmetatable

local wallpaper_tab = {
	mt = {},
}

local function set_wallpapers(empty_widget, wallpapers_layout, content, stack, wallpapers)
    if wallpapers then
        wallpapers_layout:set_entries(wallpapers)
        if gtable.count_keys(wallpapers) == 0 then
            stack:raise_widget(empty_widget)
        else
            stack:raise_widget(content)
        end
        collectgarbage("collect")
        collectgarbage("collect")
    end
end

local function wallpapers(entry_template)
	local wallpapers_layout = wibox.widget({
		layout = widgets.scrollable_grid,
		forced_height = dpi(590),
		widget_template = wibox.widget({
			layout = wibox.layout.fixed.vertical,
			spacing = dpi(15),
			{
				widget = widgets.text_input,
				id = "text_input_role",
				forced_height = dpi(55),
				unfocus_on_client_clicked = false,
				selection_bg = beautiful.icons.computer.color,
				widget_template = wibox.widget({
					widget = widgets.background,
					shape = library.ui.rrect(),
					bg = beautiful.colors.surface,
					{
						widget = wibox.container.margin,
						margins = dpi(15),
						{
							layout = wibox.layout.fixed.horizontal,
							spacing = dpi(15),
							{
								widget = widgets.text,
								icon = beautiful.icons.magnifying_glass,
								color = beautiful.icons.computer.color,
							},
							{
								layout = wibox.layout.stack,
								{
									widget = wibox.widget.textbox,
									id = "placeholder_role",
									text = "Search:",
								},
								{
									widget = wibox.widget.textbox,
									id = "text_role",
								},
							},
						},
					},
				}),
			},
			{
				layout = wibox.layout.fixed.horizontal,
				spacing = dpi(10),
				{
					layout = wibox.layout.grid,
					id = "grid_role",
					orientation = "horizontal",
					homogeneous = true,
					spacing = dpi(5),
					column_count = 5,
					row_count = 3,
					expand = true,
				},
				{
					layout = wibox.container.rotate,
					direction = "west",
					{
						widget = wibox.widget.slider,
						id = "scrollbar_role",
						forced_width = dpi(5),
						forced_height = dpi(10),
						minimum = 1,
						value = 1,
						bar_shape = library.ui.rrect(),
						bar_height = 3,
						bar_color = beautiful.colors.transparent,
						bar_active_color = beautiful.colors.transparent,
						handle_width = dpi(50),
						handle_shape = library.ui.rrect(),
						handle_color = beautiful.colors.on_background,
					},
				},
			},
		}),
		entry_template = entry_template,
	})

	SETTINGS_APP_NAVIGATOR:connect_signal("select", function()
		wallpapers_layout:get_text_input():unfocus()
	end)

	SETTINGS_APP:connect_signal("request::unmanage", function()
		wallpapers_layout:get_text_input():unfocus()
	end)

	SETTINGS_APP:connect_signal("unfocus", function()
		wallpapers_layout:get_text_input():unfocus()
	end)

	SETTINGS_APP:connect_signal("mouse::leave", function()
		wallpapers_layout:get_text_input():unfocus()
	end)

	theme_daemon:connect_signal("tab::select", function()
		wallpapers_layout:get_text_input():unfocus()
	end)

    return wallpapers_layout
end

local function color_button(index)
    local background = wibox.widget {
        widget = wibox.container.background,
        forced_width = dpi(200),
        forced_height = dpi(40),
        shape = library.ui.rrect(),
    }

    local color_text_input = wibox.widget {
        widget = widgets.text_input,
        unfocus_on_client_clicked = false,
        size = 12,
        selection_bg = beautiful.icons.computer.color,
        widget_template = wibox.widget {
            widget = wibox.widget.textbox,
            id = "text_role",
            halign = "center",
		}
    }

    local color_button = wibox.widget {
        layout = wibox.layout.fixed.vertical,
        spacing = dpi(5),
        {
            widget = widgets.text,
            halign = "center",
            size = 12,
            text = index
        },
        {
            widget = widgets.button.normal,
            on_secondary_release = function()
                theme_daemon:set_color(index)
            end,
            {
                layout = wibox.layout.stack,
                background,
                color_text_input
            }
        }
    }

    theme_daemon:connect_signal("colorscheme::generation::success", function(self, colors, wallpaper)
        if wallpaper == theme_daemon:get_selected_colorscheme() then
            local color = colors[index]
            if library.color.is_dark(color) then
                color_text_input:set_text_color(beautiful.colors.white)
            else
                color_text_input:set_text_color(beautiful.colors.black)
            end
            color_text_input:set_text(color)
            background.bg = color
        end
    end)

    color_text_input:connect_signal("unfocus", function(self, context, text)
        theme_daemon:set_color(index, text)
    end)

    return color_button
end

local function actions()
    local colors = wibox.widget {
        widget = wibox.layout.grid,
        spacing = dpi(15),
        row_count = 2,
        column_count = 8,
        expand = true
    }

    local spinning_circle = widgets.spinning_circle {
        forced_width = dpi(250),
        forced_height = dpi(250),
        thickness = dpi(30),
        run_by_default = false
    }

    local run_on_set = wibox.widget {
        widget = widgets.text_input,
        id = "text_input_role",
        forced_height = dpi(55),
        initial = theme_daemon:get_run_on_set(),
        unfocus_on_client_clicked = false,
        selection_bg = beautiful.icons.computer.color,
        widget_template = wibox.widget {
            widget = widgets.background,
            shape = library.ui.rrect(),
            bg = beautiful.colors.surface,
            {
                widget = wibox.container.margin,
                margins = dpi(15),
                {
                    layout = wibox.layout.fixed.horizontal,
                    spacing = dpi(15),
                    {
                        widget = widgets.text,
                        icon = beautiful.icons.computer,
                        color = beautiful.icons.computer.color
                    },
                    {
                        layout = wibox.layout.stack,
                        {
                            widget = wibox.widget.textbox,
                            id = "placeholder_role",
                            text = "Run:"
                        },
                        {
                            widget = wibox.widget.textbox,
                            id = "text_role"
                        }
                    }
                }
            }
        }
    }

    run_on_set:connect_signal("property::text", function(self, text)
        theme_daemon:set_run_on_set(text)
    end)

    local light_dark = wibox.widget {
        widget = widgets.button.normal,
        color = beautiful.icons.computer.color,
        on_release = function()
            theme_daemon:toggle_dark_light()
        end,
        {
            widget = widgets.text,
            color = beautiful.colors.on_accent,
            size = 15,
            text = "Light",
        }
    }

    local reset_colorscheme = wibox.widget {
        widget = widgets.button.normal,
        color = beautiful.icons.computer.color,
        on_release = function()
            theme_daemon:reset_colorscheme()
        end,
        {
            widget = widgets.text,
            color = beautiful.colors.on_accent,
            size = 15,
            text = "Reset Colorscheme",
        }
    }

    local save_colorscheme = wibox.widget {
        widget = widgets.button.normal,
        color = beautiful.icons.computer.color,
        on_release = function()
            theme_daemon:save_colorscheme()
        end,
        {
            widget = widgets.text,
            color = beautiful.colors.on_accent,
            size = 15,
            text = "Save Colorscheme",
        }
    }

    local set_wallpaper = wibox.widget {
        widget = widgets.button.normal,
        color = beautiful.icons.computer.color,
        on_release = function()
            theme_daemon:set_wallpaper(theme_daemon:get_selected_colorscheme())
        end,
        {
            widget = widgets.text,
            color = beautiful.colors.on_accent,
            size = 15,
            text = "Set Wallpaper",
        }
    }

    local set_colorscheme = wibox.widget {
        widget = widgets.button.normal,
        color = beautiful.icons.computer.color,
        on_release = function()
            theme_daemon:set_colorscheme(theme_daemon:get_selected_colorscheme())
        end,
        {
            widget = widgets.text,
            color = beautiful.colors.on_accent,
            size = 15,
            text = "Set Colorscheme",
        }
    }

    local set_both = wibox.widget {
        widget = widgets.button.normal,
        color = beautiful.icons.computer.color,
        on_release = function()
            theme_daemon:set_wallpaper(theme_daemon:get_selected_colorscheme())
            theme_daemon:set_colorscheme(theme_daemon:get_selected_colorscheme())
        end,
        {
            widget = widgets.text,
            color = beautiful.colors.on_accent,
            size = 15,
            text = "Set Both",
        }
    }

    local widget = wibox.widget {
        layout = wibox.layout.fixed.vertical,
        spacing = dpi(15),
        colors,
        run_on_set,
        {
            layout = wibox.layout.grid,
            spacing = dpi(10),
            row_count = 3,
            column_count = 3,
            horizontal_expand = true,
            light_dark,
            reset_colorscheme,
            save_colorscheme,
            set_wallpaper,
            set_colorscheme,
            set_both
        }
    }

    local stack = wibox.widget {
        layout = wibox.layout.stack,
        forced_height = dpi(380),
        top_only = true,
        spinning_circle,
        widget
    }

    theme_daemon:connect_signal("colorscheme::generation::start", function()
        spinning_circle:start()
        stack:raise_widget(spinning_circle)
    end)

    theme_daemon:connect_signal("colorscheme::generation::error", function()
        spinning_circle:stop()
        stack:raise_widget(widget)
    end)

    theme_daemon:connect_signal("colorscheme::generation::success", function(self, colors, wallpaper)
        if wallpaper == theme_daemon:get_selected_colorscheme() then
            if library.color.is_dark(colors[1]) then
                light_dark:set_text("Light")
            else
                light_dark:set_text("Dark")
            end
            spinning_circle:stop()
            stack:raise_widget(widget)
        end
    end)

    for i = 1, 16 do
        colors:add(color_button(i))
    end

    return stack
end

local function new(type, entry_template)
	local empty_widget = wibox.widget({
		widget = wibox.container.margin,
		margins = {
			top = dpi(250),
		},
		{
			layout = wibox.layout.fixed.vertical,
			spacing = dpi(15),
			{
				widget = widgets.text,
				halign = "center",
				icon = beautiful.icons.spraycan,
				size = 50,
			},
			{
				widget = widgets.text,
				halign = "center",
				size = 15,
				text = "It's empty out here ):",
			},
		},
	})

	local wallpapers_layout = wallpapers(entry_template)

	local content = wibox.widget({
		layout = wibox.layout.overflow.vertical,
		spacing = dpi(15),
        scrollbar_widget = widgets.scrollbar,
        scrollbar_width = dpi(10),
        step = 50,
		wallpapers_layout,
		actions(),
	})

	local stack = wibox.widget({
		layout = wibox.layout.stack,
		top_only = true,
		empty_widget,
		content,
	})

	theme_daemon:connect_signal("wallpapers::" .. type, function(self, wallpapers)
		set_wallpapers(empty_widget, wallpapers_layout, content, stack, wallpapers)
	end)

	return stack
end

function wallpaper_tab.mt:__call(type, entry_template)
	return new(type, entry_template)
end

return setmetatable(wallpaper_tab, wallpaper_tab.mt)
