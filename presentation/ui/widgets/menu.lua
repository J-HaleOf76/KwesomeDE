-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2022 Kasper24
-------------------------------------------

local awful = require("awful")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gmath = require("gears.math")
local wibox = require("wibox")
local ebwidget = require("presentation.ui.widgets.button.elevated")
local twidget = require("presentation.ui.widgets.text")
local cbwidget = require("presentation.ui.widgets.checkbox")
local beautiful = require("beautiful")
local helpers = require("helpers")
local dpi = beautiful.xresources.apply_dpi
local setmetatable = setmetatable
local ipairs = ipairs
local capi = { awesome = awesome, tag = tag, client = client, mouse = mouse }

local menu = { mt = {} }

function menu:set_pos(args)
    args = args or {}

    local coords = args.coords
    local wibox = args.wibox
    local widget = args.widget
    local offset = args.offset or { x = 0, y = 0 }

    if offset.x == nil then offset.x = 0 end
    if offset.y == nil then offset.y = 0 end

    local screen_workarea = awful.screen.focused().workarea
    local screen_w = screen_workarea.x + screen_workarea.width
    local screen_h = screen_workarea.y + screen_workarea.height

    if not coords and wibox and widget then
        coords = helpers.ui.get_widget_geometry(wibox, widget)
    else
        coords = args.coords or capi.mouse.coords()
    end

    if coords.x + self.width > screen_w then
        if self.parent_menu ~= nil then
            self.x = coords.x - (self.width * 2) - offset.x
        else
            self.x = coords.x - self.width + offset.x
        end
    else
        self.x = coords.x + offset.x
    end

    if coords.y + self.height > screen_h then
        self.y = screen_h - self.height + offset.y
    else
        self.y = coords.y + offset.y
    end
end

function menu:hide_parents_menus()
    if self.parent_menu ~= nil then
        self.parent_menu:hide(true)
    end
end

function menu:hide_children_menus()
    for _, button in ipairs(self.widget.children) do
        if button.sub_menu ~= nil then
            button.sub_menu:hide()
            button:get_children_by_id("button")[1]:turn_off()
        end
    end
end

function menu:hide(hide_parents)
    if self.visible == false then
        return
    end

    -- No animation for hiding
    self.widget.forced_height = 1
    self.visible = false
    -- Set the anim back to starting position
    self.animation.pos = 1

    -- Hides all child menus
    self:hide_children_menus()

    if hide_parents == true then
        self:hide_parents_menus()
    end
end

function menu:show(args)
    if self.visible == true then
        return
    end

    self.can_hide = false

    gtimer { timeout = 0.1, autostart = true, call_now = false, single_shot = true, callback = function()
        self.can_hide = true
    end }

    -- Hide sub menus belonging to the menu of self
    if self.parent_menu ~= nil then
        for _, button in ipairs(self.parent_menu.widget.children) do
            if button.sub_menu ~= nil and button.sub_menu ~= self then
                button.sub_menu:hide()
                button:get_children_by_id("button")[1]:turn_off()
            end
        end
    end

    self:set_pos(args)
    self.animation:set(self.menu_height)
    self.visible = true

    capi.awesome.emit_signal("menu::toggled_on", self)
end

function menu:toggle(args)
    if self.visible == true then
        self:hide()
    else
        self:show(args)
    end
end

function menu:add(widget, index)
    if widget.sub_menu then
        widget.sub_menu.parent_menu = self
    end

    if widget:get_children_by_id("button")[1] ~= nil then
        widget:get_children_by_id("button")[1].menu = self
    end

    local height_without_dpi = widget.forced_height * 96 / beautiful.xresources.get_dpi()
    self.menu_height = self.menu_height + height_without_dpi

    if index == nil then
        self.widget:add(widget)
    else
        self.widget:insert(index, widget)
    end
end

function menu:remove(index)
    self.menu_height = self.menu_height - self.widget.children[index].forced_height
    self.widget:remove(index)
end

function menu:reset()
    self.menu_height = 0
    self.widget:reset()
end

function menu.menu(widgets, width)
    local menu_container = wibox.widget
    {
        layout = wibox.layout.fixed.vertical,
        forced_height = 0,
    }

    local widget = awful.popup
    {
        x = 32500,
        type = "menu",
        visible = false,
        ontop = true,
        minimum_width = width or dpi(300),
        maximum_width = width or dpi(300),
        shape = helpers.ui.rrect(beautiful.border_radius),
        bg = beautiful.colors.background,
        widget = menu_container
    }
	gtable.crush(widget, menu, true)

    -- -- Setup animations
	widget.animation = helpers.animation:new
	{
		pos = 1,
		easing = helpers.animation.easing.outInCirc,
		duration = 0.4,
		update = function(self, pos)
			menu_container.forced_height = dpi(pos)
		end
	}

    capi.awesome.connect_signal("root::pressed", function()
        if widget.can_hide == true then
            widget:hide(true)
        end
    end)

    capi.client.connect_signal("button::press", function()
        if widget.can_hide == true then
            widget:hide(true)
        end
    end)

    capi.tag.connect_signal("property::selected", function(t)
        widget:hide(true)
    end)

    capi.awesome.connect_signal("menu::toggled_on", function(menu)
        if menu ~= widget and menu.parent_menu == nil then
            widget:hide(true)
        end
    end)

    widget.menu_height = 0
    for _, menu_widget in ipairs(widgets) do
        widget:add(menu_widget)
    end

    return widget
end

function menu.sub_menu_button(args)
    args = args or {}

    args.icon = args.icon or nil
    args.text = args.text or ""
    args.sub_menu = args.sub_menu or nil

    local icon = args.icon ~= nil
    and wibox.widget
    {
        widget = twidget,
        size = (args.icon.size or 20) / 1.5,
        icon = args.icon,
    } or nil

    local widget = wibox.widget
    {
        widget = wibox.container.margin,
        forced_height = dpi(45),
        sub_menu = args.sub_menu,
        margins = dpi(5),
        {
            widget = ebwidget.state,
            id = "button",
            normal_shape = helpers.ui.rrect(0),
            on_hover = function(self)
                local coords = helpers.ui.get_widget_geometry(self.menu, self)
                coords.x = coords.x + self.menu.x + self.menu.width
                coords.y = coords.y + self.menu.y
                args.sub_menu:show{coords = coords, offset = { x = -5 }}
                self:turn_on()
            end,
            child =
            {
                layout = wibox.layout.align.horizontal,
                forced_width = dpi(270),
                {
                    layout = wibox.layout.fixed.horizontal,
                    spacing = dpi(15),
                    icon,
                    {
                        widget = twidget,
                        size = 12,
                        text = args.text,
                    },
                },
                nil,
                {
                    widget = twidget,
                    icon = beautiful.icons.chevron.right,
                    size = 12,
                },
            }
        }
    }

    return widget
end

function menu.button(args)
    args = args or {}

    args.icon = args.icon or nil
    args.image = args.image
    args.text = args.text or ""
    args.on_press = args.on_press or nil

    local icon = nil

    if args.icon ~= nil then
        icon = wibox.widget
        {
            widget = twidget,
            size = (args.icon.size or 20) / 1.5,
            icon = args.icon,
        }
    elseif args.image ~= nil then
        icon = wibox.widget
        {
            widget = wibox.widget.imagebox,
            image = args.image,
        }
    end

    local text_widget = wibox.widget
    {
        widget = twidget,
        size = 12,
        text = args.text,
    }

    return wibox.widget
    {
        widget = wibox.container.margin,
        forced_height = dpi(45),
        margins = dpi(5),
        {
            widget = ebwidget.normal,
            id = "button",
            normal_shape = helpers.ui.rrect(0),
            on_release = function(self)
                self.menu:hide(true)
                args.on_press(self, text_widget)
            end,
            on_hover = function(self)
                self.menu:hide_children_menus()
            end,
            child =
            {
                layout = wibox.layout.align.horizontal,
                forced_width = dpi(270),
                {
                    layout = wibox.layout.fixed.horizontal,
                    spacing = dpi(15),
                    icon,
                    text_widget
                },
                nil,
            }
        }
    }

end

function menu.checkbox_button(args)
    args = args or {}

    args.icon = args.icon or nil
    args.image = args.image
    args.text = args.text or ""
    args.color = args.color or beautiful.colors.random_accent_color()
    args.on_by_default = args.on_by_default or nil
    args.on_press = args.on_press or nil

    local icon = nil

    if args.icon ~= nil then
        icon = wibox.widget
        {
            widget = twidget,
            size = (args.icon.size or 20) / 1.5,
            text = args.icon,
        }
    elseif args.image ~= nil then
        icon = wibox.widget
        {
            widget = wibox.widget.imagebox,
            image = args.image,
        }
    end

    local checkbox = cbwidget{}
    checkbox:set_color(args.color)

    local widget = wibox.widget
    {
        widget = wibox.container.margin,
        forced_height = dpi(45),
        margins = dpi(5),
        {
            widget = wibox.container.place,
            halign = "left",
            {
                widget = ebwidget.normal,
                id = "button",
                normal_shape = helpers.ui.rrect(0),
                on_release = function(self)
                    args.on_press()
                end,
                on_hover = function(self)
                    self.menu:hide_children_menus()
                end,
                child =
                {
                    layout = wibox.layout.fixed.horizontal,
                    {
                        layout = wibox.layout.fixed.horizontal,
                        forced_width = dpi(230),
                        spacing = dpi(15),
                        icon,
                        {
                            widget = twidget,
                            size = 12,
                            text = args.text,
                        },
                    },
                    checkbox
                }
            }
        }
    }

    function widget:turn_on()
        checkbox:turn_on()
    end

    function widget:turn_off()
        checkbox:turn_off()
    end

    return widget
end

function menu.separator()
    return wibox.widget
    {
        widget = wibox.container.margin,
        forced_height = dpi(15),
        margins = dpi(5),
        {
            widget = wibox.widget.separator,
            orientation = "horizontal",
            thickness = dpi(1),
            color = beautiful.colors.on_background .. "64"
        }
    }
end

function menu.mt:__call(...)
    return menu.menu(...)
end

return setmetatable(menu, menu.mt)