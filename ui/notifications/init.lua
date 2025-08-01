-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2025 Kasper24
-------------------------------------------
local awful = require("awful")
local gtimer = require("gears.timer")
local ruled = require("ruled")
local wibox = require("wibox")
local widgets = require("ui.widgets")
local beautiful = require("beautiful")
local notifications_daemon = require("daemons.system.notifications")
local library = require("library")
local dpi = beautiful.xresources.apply_dpi
local max = math.max
local ipairs = ipairs
local string = string
local table = table

local function play_sound(n)
	if n.category == "device.added" or n.category == "network.connected" then
		awful.spawn("canberra-gtk-play -i service-login", false)
	elseif n.category == "device.removed" or n.category == "network.disconnected" then
		awful.spawn("canberra-gtk-play -i service-logout", false)
	elseif
		n.category == "device.error"
		or n.category == "im.error"
		or n.category == "network.error"
		or n.category == "transfer.error"
	then
		awful.spawn("canberra-gtk-play -i dialog-warning", false)
	elseif n.category == "email.arrived" then
		awful.spawn("canberra-gtk-play -i message", false)
	else
		awful.spawn("canberra-gtk-play -i bell", false)
	end
end

local function get_notification_position(n, screen)
	local placement = awful.placement.top_right(n.widget, {
		honor_workarea = true,
		honor_padding = true,
		attach = true,
		pretend = true,
		margins = dpi(30),
	})
	local x = placement.x
	local y = placement.y

	if #screen.notifications > 1 then
		local parent = screen.notifications[#screen.notifications - 1]
		y = parent.widget.y + parent.widget.height + dpi(30)
	end

	return { x = x, y = y }
end

local function icon_widget(n)
	if n.font_icon == nil then
		return wibox.widget({
			widget = wibox.container.constraint,
			strategy = "max",
			height = dpi(40),
			width = dpi(40),
			{
				widget = wibox.widget.imagebox,
				clip_shape = library.ui.rrect(),
				image = n.icon,
			},
		})
	else
		return wibox.widget({
			widget = widgets.text,
			size = 30,
			icon = n.font_icon,
		})
	end
end

local function actions_widget(n)
	local actions = wibox.widget({
		layout = wibox.layout.flex.horizontal,
		spacing = dpi(15),
	})

	for _, action in ipairs(n.actions) do
		local button = wibox.widget({
			widget = widgets.button.normal,
			color = beautiful.colors.surface,
			on_release = function()
				action:invoke()
			end,
			{
				widget = widgets.text,
				color = beautiful.colors.on_surface,
				size = 12,
				text = action.name,
			},
		})
		actions:add(button)
	end

	return actions
end

local function destroy_notif(n, screen)
	if n == nil or n.widget == nil then
		return
	end

	local min_y = awful.placement.top_right(n.widget, {
		honor_workarea = true,
		honor_padding = true,
		attach = true,
		pretend = true,
		margins = dpi(30),
	}).y

	library.table.remove_value(screen.notifications, n)
	n.destroyed = true
	local destroyed_n_height = n.widget.height
	for _, n in ipairs(screen.notifications) do
		if #screen.notifications > 0 and n.widget.y ~= min_y then
			n.anim:set({ y = n.widget.y - destroyed_n_height - dpi(30), height = 300 })
		end
	end

	n.widget.widget:get_children_by_id("top_row")[1]:set_third(nil)
	n.anim:set({ y = n.widget.y, height = 1 })
	n:destroy()
end

local function create_notification(n, screen)
	table.insert(screen.notifications, n)

	n:set_timeout(4294967)

	local app_icon = wibox.widget({
		widget = widgets.icon,
		size = 30,
		halign = "center",
		valign = "center",
		clip_shape = library.ui.rrect(),
		icon = n.app_icon,
	})

	local app_name = wibox.widget({
		widget = widgets.text,
		size = 12,
		text = n.app_name:gsub("^%l", string.upper),
	})

	local dismiss = wibox.widget({
		widget = widgets.button.normal,
		on_release = function()
			destroy_notif(n, screen)
		end,
		{
			widget = widgets.text,
			color = beautiful.colors.on_background,
			size = 12,
			icon = beautiful.icons.xmark,
		},
	})

	local timeout_arc = wibox.widget({
		widget = widgets.arcchart,
		forced_width = dpi(45),
		forced_height = dpi(45),
		max_value = 100,
		min_value = 0,
		value = 0,
		thickness = dpi(6),
		rounded_edge = true,
		bg = beautiful.colors.surface,
		colors = {
			beautiful.colors.accent,
		},
		dismiss,
	})

	local title = wibox.widget({
		widget = wibox.container.scroll.horizontal,
		step_function = wibox.container.scroll.step_functions.waiting_nonlinear_back_and_forth,
		speed = 50,
		{
			widget = widgets.text,
			size = 15,
			bold = true,
			text = n.title,
		},
	})

	local bar = wibox.widget({
		widget = widgets.background,
		forced_height = dpi(10),
		shape = library.ui.rrect(),
		bg = beautiful.colors.accent,
	})

	local message = wibox.widget({
		widget = wibox.container.constraint,
		strategy = "max",
		height = dpi(60),
		{
			layout = wibox.layout.overflow.vertical,
			scrollbar_widget = widgets.scrollbar,
			scrollbar_width = dpi(10),
			scroll_speed = 3,
			{
				widget = widgets.text,
				size = 15,
				text = n.message,
			},
		},
	})

	n.widget = widgets.popup({
		minimum_width = dpi(400),
		minimum_height = dpi(50),
		maximum_width = dpi(400),
		offset = { y = dpi(30) },
		ontop = true,
		shape = library.ui.rrect(),
		bg = beautiful.colors.background,
		border_width = 0,
		widget = wibox.widget({
			widget = wibox.container.background,
			{
				widget = wibox.container.margin,
				margins = dpi(25),
				{
					layout = wibox.layout.fixed.vertical,
					spacing = dpi(15),
					{
						layout = wibox.layout.align.horizontal,
						id = "top_row",
						{
							layout = wibox.layout.fixed.horizontal,
							spacing = dpi(15),
							app_icon,
							app_name,
						},
						nil,
					},
					{
						layout = wibox.layout.fixed.horizontal,
						spacing = dpi(15),
						icon_widget(n),
						title,
					},
					bar,
					message,
					actions_widget(n),
				},
			},
		}),
	})

	local timeout_arc_anim = nil
	if n.urgency ~= "critical" then
		timeout_arc_anim = library.animation:new({
			duration = 5,
			target = 100,
			easing = library.animation.easing.linear,
			override_instant = true,
			reset_on_stop = false,
			update = function(self, pos)
				timeout_arc.value = pos
			end,
			signals = {
				["ended"] = function()
					destroy_notif(n, screen)
				end,
			},
		})

		n.widget:connect_signal("mouse::enter", function()
			timeout_arc_anim:stop()
		end)

		n.widget:connect_signal("mouse::leave", function()
			timeout_arc_anim:set()
		end)
	end

	local pos = get_notification_position(n, screen)
	n.widget.x = pos.x
	n.widget.y = pos.y

	n.anim = library.animation:new({
		pos = { y = pos.y, height = 1 },
		duration = 0.2,
		easing = library.animation.easing.linear,
		update = function(self, pos)
			if pos.y then
				n.widget.y = pos.y
			end
			if pos.height then
				n.widget.maximum_height = dpi(max(1, pos.height))
			end
		end,
		signals = {
			["started"] = function()
				screen.animating_notification = true
			end,
			["ended"] = function()
				screen.animating_notification = false

				if n.destroyed then
					n.anim = nil
					n.widget.visible = false
					n.widget = nil
				else
					if n.urgency ~= "critical" then
						n.widget.widget:get_children_by_id("top_row")[1]:set_third(timeout_arc)
						if timeout_arc_anim then
							timeout_arc_anim:set()
						end
					else
						n.widget.widget:get_children_by_id("top_row")[1]:set_third(dismiss)
					end
				end
			end,
		},
	})
	n.anim:set({ y = pos.y, height = 300 })

	play_sound(n)
end

ruled.notification.connect_signal("request::rules", function()
	ruled.notification.append_rule({
		rule = {
			app_name = "networkmanager-dmenu",
		},
		properties = {
			icon = beautiful.get_svg_icon({ "cs-network" }),
		},
	})
	ruled.notification.append_rule({
		rule = {
			app_name = "blueman",
		},
		properties = {
			icon = beautiful.get_svg_icon({ "blueman-device" }),
		},
	})
end)

notifications_daemon:connect_signal("display::notification", function(self, n)
	gtimer.start_new(0.2, function()
		local screen = awful.screen.focused()
		if #screen.notifications > 2 or screen.animating_notification then
			return true
		end

		create_notification(n, screen)
		return false
	end)
end)

awful.screen.connect_for_each_screen(function(s)
	s.notifications = {}
end)

require(... .. ".bluetooth")
require(... .. ".breaking_change")
require(... .. ".email")
require(... .. ".error")
require(... .. ".github")
require(... .. ".gitlab")
require(... .. ".lock")
require(... .. ".network")
require(... .. ".package_manager")
require(... .. ".playerctl")
require(... .. ".record")
require(... .. ".screenshot")
require(... .. ".udisks")
require(... .. ".upower")
require(... .. ".usb")
