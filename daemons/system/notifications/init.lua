-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2025 Kasper24
-------------------------------------------
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gstring = require("gears.string")
local gdebug = require("gears.debug")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local library = require("library")
local filesystem = require("external.filesystem")
local json = require("external.json")
local ipairs = ipairs
local os = os

local notifications = {}
local instance = nil

local PATH = filesystem.filesystem.get_data_dir("notifications")
local ICONS_PATH = PATH .. "icons/"
local DATA_PATH = PATH .. "data.json"

local function save_notification(self, notification)
	local icon_path = ICONS_PATH .. notification.uuid .. ".svg"

	table.insert(self._private.notifications, {
		uuid = notification.uuid,
		app_icon_names = notification.app_icon.names,
		app_name = notification.app_name,
		font_icon = notification.font_icon,
		icon = icon_path,
		title = gstring.xml_unescape(notification.title),
		message = gstring.xml_unescape(notification.message),
		time = notification.time,
	})

	filesystem.filesystem.make_directory(ICONS_PATH)
	wibox.widget.draw_to_svg_file(
		wibox.widget({
			widget = wibox.widget.imagebox,
			forced_width = 35,
			forced_height = 35,
			image = notification.icon,
		}),
		icon_path,
		35,
		35
	)

	self._private.save_timer:again()
end

local function sort_notifications(a, b)
	local dateA = library.string.parse_date(a.time)
	local dateB = library.string.parse_date(b.time)

	return dateA < dateB
end

local function read_notifications(self)
	local file = filesystem.file.new_for_path(DATA_PATH)
	file:read(function(error, content)
		if error == nil then
			self._private.notifications = json.decode(content) or {}
			table.sort(self._private.notifications, sort_notifications)

			if #self._private.notifications > 0 then
				for _, notification in ipairs(self._private.notifications) do
					notification.app_icon = beautiful.get_svg_icon(notification.app_icon_names)
					local icon = filesystem.file.new_for_path(notification.icon)
					if notification.font_icon == nil then
						icon:exists(function(error, exists)
							if error ~= nil or exists == false then
								notification.font_icon = beautiful.icons.message
							end

							self:emit_signal("display::panel", notification)
						end)
					else
						self:emit_signal("display::panel", notification)
					end
				end
			else
				self:emit_signal("empty")
			end
		else
			self:emit_signal("empty")
		end
	end)
end

local function create_notification(notification, self)
	if notification.title == "" or notification.title == nil then
		notification.title = notification.app_name
	end

	notification.app_icon = beautiful.get_app_svg_icon(notification._private.app_icon or { notification.app_name })
	notification.font_icon = notification._private.font_icon

	if type(notification.icon) == "table" then
		notification.icon = beautiful.get_svg_icon(notification.icon)
	end

	if (notification.icon == "" or notification.icon == nil) and notification.font_icon == nil then
		notification.font_icon = beautiful.icons.message
		notification.icon = beautiful.get_svg_icon({ "preferences-desktop-notification-bell" })
	end

	notification.time = os.date("%Y-%m-%dT%H:%M:%S")
	notification.uuid = library.string.random_uuid()
	save_notification(self, notification)
	self:emit_signal("display::panel", notification)

	if self:is_suspended() == false or notification.ignore_suspend == false then
		self:emit_signal("display::notification", notification)
	end
end
function notifications:remove_all_notifications()
	self._private.notifications = {}
	self._private.save_timer:again()
	filesystem.filesystem.remove_directory(ICONS_PATH)
	self:emit_signal("empty")
end

function notifications:remove_notification(notification)
	for index, looped_notification in ipairs(self._private.notifications) do
		if looped_notification.uuid == notification.uuid then
			local file = filesystem.file.new_for_path(looped_notification.icon)
			file:delete()
			table.remove(self._private.notifications, index)
			self._private.save_timer:again()
		end
	end

	if #self._private.notifications == 0 then
		self:emit_signal("empty")
	end
end

function notifications:is_suspended()
	return self.suspended
end

function notifications:block_on_locked()
	if self.suspended == false then
		self.suspended = true
		self.was_not_suspended = true
	end
end

function notifications:unblock_on_unlocked()
	if self.was_not_suspended == true then
		self.suspended = false
		self.was_not_suspended = nil
	end
end

function notifications:set_dont_disturb(value)
	if self.suspended ~= value then
		self.suspended = value
		library.settings["notifications.dont_disturb"] = value
		self:emit_signal("state", value)
	end
end

function notifications:toggle_dont_disturb()
	if self.suspended == true then
		self:set_dont_disturb(false)
	else
		self:set_dont_disturb(true)
	end
end

local function new()
	local ret = gobject({})
	gtable.crush(ret, notifications, true)

	ret._private = {}
	ret._private.notifications = {}

	local file = filesystem.file.new_for_path(DATA_PATH)
	ret._private.save_timer = gtimer({
		timeout = 1,
		autostart = false,
		single_shot = true,
		callback = function()
			local _notifications_status, notifications = pcall(function()
				return json.encode(ret._private.notifications)
			end)
			if not _notifications_status or not notifications then
				gdebug.print_warning("Failed to encode notifications! " .. "Notifications will not be saved. ")
			else
				file:write(notifications)
			end
		end,
	})

	gtimer.delayed_call(function()
		ret:set_dont_disturb(library.settings["notifications.dont_disturb"])
		read_notifications(ret)
	end)

	naughty.connect_signal("request::action_icon", function(a, context, hints)
		a.icon = beautiful.get_svg_icon({ hints.id })
	end)

	naughty.connect_signal("request::display", function(notification)
		create_notification(notification, ret)
	end)

	return ret
end

if not instance then
	instance = new()
end
return instance
