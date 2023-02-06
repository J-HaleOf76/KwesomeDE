-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2022 Kasper24
-------------------------------------------
local lgi = require("lgi")
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local wibox = require("wibox")
local widgets = require("ui.widgets")
local beautiful = require("beautiful")
local bluetooth_daemon = require("daemons.hardware.bluetooth")
local helpers = require("helpers")
local dpi = beautiful.xresources.apply_dpi
local capi = {
    awesome = awesome
}

local bluetooth = {}
local instance = nil

function bluetooth:show(next_to)
    self.widget.screen = awful.screen.focused()
    self.widget:move_next_to(next_to)
    self.widget.visible = true
    self:emit_signal("visibility", true)
end

function bluetooth:hide()
    self.widget.visible = false
    self:emit_signal("visibility", false)
end

function bluetooth:toggle(next_to)
    if self.widget.visible then
        self:hide()
    else
        self:show(next_to)
    end
end

local function device_widget(device, path, layout, accent_color)
    local widget = nil
    local anim = nil

    local device_icon = wibox.widget {
        widget = wibox.widget.imagebox,
        forced_width = dpi(50),
        forced_height = dpi(50),
        image = helpers.icon_theme:get_icon_path(device.Icon or "bluetooth")
    }

    local name = wibox.widget {
        widget = widgets.text,
        forced_width = dpi(600),
        forced_height = dpi(30),
        halign = "left",
        size = 12,
        text = device.Name,
        color = beautiful.colors.on_surface
    }

    local cancel = wibox.widget {
        widget = widgets.button.text.normal,
        normal_bg = beautiful.colors.surface,
        text_normal_bg = beautiful.colors.on_surface,
        size = 12,
        text = "Cancel",
        on_press = function()
            widget:get_children_by_id("button")[1]:turn_off()
            anim:set(dpi(60))
        end
    }

    local connect_or_disconnect = wibox.widget {
        widget = widgets.button.text.normal,
        normal_bg = beautiful.colors.surface,
        text_normal_bg = beautiful.colors.on_surface,
        size = 12,
        text = device.Connected == true and "Disconnect" or "Connect",
        on_press = function()
            if device.Connected == true then
                device:DisconnectAsync()
            else
                device:ConnectAsync()
            end
        end
    }

    local trust_or_untrust = wibox.widget {
        widget = widgets.button.text.normal,
        normal_bg = beautiful.colors.surface,
        text_normal_bg = beautiful.colors.on_surface,
        size = 12,
        text = device.Trusted == true and "Untrust" or "Trust",
        on_press = function()
            local is_trusted = device.Trusted
            device:Set("org.bluez.Device1", "Trusted", lgi.GLib.Variant("b", not is_trusted))
            device.Trusted = {
                signature = "b",
                value = not is_trusted
            }
        end
    }

    local pair_or_unpair = wibox.widget {
        widget = widgets.button.text.normal,
        normal_bg = beautiful.colors.surface,
        text_normal_bg = beautiful.colors.on_surface,
        size = 12,
        text = device.Paired == true and "Unpair" or "Pair",
        on_press = function()
            if device.Paired == true then
                device:PairAsync()
            else
                device:CancelPairingAsync()
            end
        end
    }

    widget = wibox.widget {
        widget = wibox.container.constraint,
        mode = "exact",
        height = dpi(60),
        {
            widget = widgets.button.elevated.state,
            id = "button",
            on_press = function(self)
                if self._private.state == false then
                    capi.awesome.emit_signal("bluetooth_device_widget::expanded", widget)
                    anim:set(dpi(130))
                    self:turn_on()
                end
            end,
            {
                layout = wibox.layout.fixed.vertical,
                spacing = dpi(15),
                {
                    layout = wibox.layout.fixed.horizontal,
                    spacing = dpi(15),
                    device_icon,
                    name
                },
                {
                    layout = wibox.layout.flex.horizontal,
                    spacing = dpi(15),
                    connect_or_disconnect,
                    trust_or_untrust,
                    pair_or_unpair,
                    cancel
                }
            }
        }
    }

    anim = helpers.animation:new{
        pos = dpi(60),
        duration = 0.2,
        easing = helpers.animation.easing.linear,
        update = function(self, pos)
            widget.height = pos
        end
    }

    bluetooth_daemon:connect_signal(path .. "_removed", function(self)
        layout:remove_widgets(widget)
    end)

    bluetooth_daemon:connect_signal(path .. "_updated", function(self)
        connect_or_disconnect.text = device.Connected and "Disconnect" or "Connect"
        trust_or_untrust.text = device.Trusted and "Untrust" or "Trust"
        pair_or_unpair.text = device.Paired and "Unpair" or "Pair"
    end)

    capi.awesome.connect_signal("bluetooth_device_widget::expanded", function(toggled_on_widget)
        if toggled_on_widget ~= widget then
            widget:get_children_by_id("button")[1]:turn_off()
            anim:set(dpi(60))
        end
    end)

    return widget
end

local function new()
    local ret = gobject {}
    gtable.crush(ret, bluetooth, true)

    ret._private = {}

    local header = wibox.widget {
        widget = widgets.text,
        halign = "left",
        bold = true,
        color = beautiful.colors.random_accent_color(),
        text = "Bluetooth"
    }

    local scan = wibox.widget {
        widget = widgets.button.text.normal,
        text_normal_bg = beautiful.colors.on_background,
        icon = beautiful.icons.arrow_rotate_right,
        size = 15,
        on_press = function()
            bluetooth_daemon:scan()
        end
    }

    local settings = wibox.widget {
        widget = widgets.button.text.normal,
        text_normal_bg = beautiful.colors.on_background,
        icon = beautiful.icons.gear,
        size = 15,
        on_press = function()
            bluetooth_daemon:open_settings()
        end
    }

    local layout = wibox.widget {
        layout = widgets.overflow.vertical,
        forced_height = dpi(600),
        spacing = dpi(15),
        scrollbar_widget = {
            widget = wibox.widget.separator,
            shape = helpers.ui.rrect(beautiful.border_radius)
        },
        scrollbar_width = dpi(10),
        step = 50
    }

    local no_bluetooth = wibox.widget {
        widget = widgets.text,
        halign = "center",
        icon = beautiful.icons.bluetooth.off,
        size = 100
    }

    local stack = wibox.widget {
        layout = wibox.layout.stack,
        top_only = true,
        layout,
        no_bluetooth
    }

    local seperator = wibox.widget {
        widget = wibox.widget.separator,
        forced_width = dpi(1),
        forced_height = dpi(1),
        shape = helpers.ui.rrect(beautiful.border_radius),
        orientation = "horizontal",
        color = beautiful.colors.surface
    }

    local accent_color = beautiful.colors.random_accent_color()

    bluetooth_daemon:connect_signal("new_device", function(self, device, path)
        layout:add(device_widget(device, path, layout, accent_color))
        stack:raise_widget(layout)
    end)

    bluetooth_daemon:connect_signal("state", function(self, state)
        if state == false then
            stack:raise_widget(no_bluetooth)
        end
    end)

    ret.widget = widgets.popup {
        ontop = true,
        visible = false,
        minimum_width = dpi(600),
        maximum_width = dpi(600),
        shape = helpers.ui.rrect(beautiful.border_radius),
        bg = beautiful.colors.background,
        widget = {
            widget = wibox.container.margin,
            margins = dpi(25),
            {
                layout = wibox.layout.fixed.vertical,
                spacing = dpi(15),
                {
                    layout = wibox.layout.align.horizontal,
                    header,
                    nil,
                    {
                        layout = wibox.layout.fixed.horizontal,
                        spacing = dpi(15),
                        scan,
                        settings
                    }
                },
                seperator,
                stack
            }
        }
    }

    return ret
end

if not instance then
    instance = new()
end
return instance