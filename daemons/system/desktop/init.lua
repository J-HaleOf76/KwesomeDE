-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2025 Kasper24
-------------------------------------------
local Gio = require("lgi").Gio
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local library = require("library")
local filesystem = require("external.filesystem")
local json = require("external.json")
local ipairs = ipairs
local os = os
local capi = {
	screen = screen,
}

local desktop = {}
local instance = nil

local grid = {}
local desktop_icons = {}

local DATA_PATH = filesystem.filesystem.get_data_dir("desktop") .. "data.json"
local DESKTOP_PATH = "/home/" .. os.getenv("USER") .. "/Desktop"

local function get_grid_pos_from_real_pos(self, pos)
	return {
		x = pos.x / self._private.cell_size,
		y = pos.y / self._private.cell_size,
	}
end

function desktop:ask_for_new_position(widget, path)
	local new_x = library.math.round_by_factor(widget.x, self._private.cell_size)
	local new_y = library.math.round_by_factor(widget.y, self._private.cell_size)

	local new_grid_pos = get_grid_pos_from_real_pos(self, {
		x = new_x,
		y = new_y,
	})

	if
		(new_x >= awful.screen.focused().vertical_wibar.maximum_width)
		and (new_y >= awful.screen.focused().horizontal_wibar.maximum_height)
		and (grid[new_grid_pos.x][new_grid_pos.y].empty == true)
	then
		local old_grid_pos = get_grid_pos_from_real_pos(self, widget.pos_before_move)
		grid[old_grid_pos.x][old_grid_pos.y].empty = true
		grid[new_grid_pos.x][new_grid_pos.y].empty = false

		desktop_icons[path].x = new_grid_pos.x
		desktop_icons[path].y = new_grid_pos.y

		local file = filesystem.file.new_for_path(path)
		file:write(json.encode(desktop_icons))

		return {
			x = new_x,
			y = new_y,
		}
	else
		return {
			x = widget.pos_before_move.x,
			y = widget.pos_before_move.y,
		}
	end
end

local function get_position_for_new_desktop_file()
	for row, _ in ipairs(grid) do
		for column, _ in ipairs(grid[row]) do
			if grid[row][column].empty == true then
				return grid[row][column]
			end
		end
	end
end

local function on_desktop_icon_added(self, pos, path, name, mimetype)
	grid[pos.x][pos.y].empty = false
	desktop_icons[path] = {
		x = pos.x,
		y = pos.y,
	}
	self:emit_signal("new", {
		x = pos.x * self._private.cell_size,
		y = pos.y * self._private.cell_size,
	}, path, name, mimetype)

	local file = filesystem.file.new_for_path(path)
	file:write(json.encode(desktop_icons))
end

local function on_desktop_icon_removed(self, path)
	self:emit_signal(path .. "_removed")

	grid[desktop_icons[path].x][desktop_icons[path].y].empty = true

	desktop_icons[path] = nil
	local file = filesystem.file.new_for_path(path)
	file:write(json.encode(desktop_icons))
end

local function watch_desktop_directory(self)
	local watcher = library.inotify:watch(
		DESKTOP_PATH,
		{
			library.inotify.Events.create,
			library.inotify.Events.delete,
			library.inotify.Events.moved_from,
			library.inotify.Events.moved_to,
		}
	)

	watcher:connect_signal("event", function(_, event, path, file)
		if event == library.inotify.Events.create or event == library.inotify.Events.moved_to then
			local mimetype = Gio.content_type_guess(path)
			on_desktop_icon_added(self, get_position_for_new_desktop_file(), path, file, mimetype)
		elseif
			event == library.inotify.Events.create .. ",isdir"
			or event == library.inotify.Events.moved_to .. ",isdir"
		then
			on_desktop_icon_added(self, get_position_for_new_desktop_file(), path, file, "folder")
		elseif
			event == library.inotify.Events.delete
			or event == library.inotify.Events.moved_from
			or event == library.inotify.Events.delete .. ",isdir"
			or event == library.inotify.Events.moved_from .. ",isdir"
		then
			on_desktop_icon_removed(self, path)
		end
	end)
end

local function scan_for_desktop_files_on_init(self)
	local file = filesystem.file.new_for_path(DATA_PATH)
	file:read(function(error, content)
		if error == nil then
			local old_desktop_icons = {}
			old_desktop_icons = json.decode(content) or {}
			filesystem.filesystem.list_contents(DESKTOP_PATH, "", function(error, list)
				if error == nil then
					for index, file in ipairs(list) do
						local name = info:get_name()
						local path = string.format("%s/%s", DESKTOP_PATH, info:get_name())

						if path:find("/home/" .. os.getenv("USER") .. "/Desktop/.", 1, true) == nil then
							local mimetype = "folder"
							local file_type = file:get_file_type()
							if file_type == "REGULAR" and file:get_attribute_boolean("access::can-read") then
								mimetype = Gio.content_type_guess(path)
							end

							local name = path:sub(library.string.find_last(path, "/") + 1, #path)
							local pos = nil
							if old_desktop_icons[path] ~= nil then
								pos = old_desktop_icons[path]
							else
								pos = get_position_for_new_desktop_file()
							end
							on_desktop_icon_added(self, pos, path, name, mimetype)
						end
					end
				end
			end)
		end
	end)
end

local function generate_grid()
	local rows = (capi.screen.primary.geometry.width - 100) / 100
	local columns = (capi.screen.primary.geometry.height - 100) / 100
	for i = 1, rows do
		grid[i] = {}
		for j = 1, columns do
			grid[i][j] = {
				x = i,
				y = j,
				empty = true,
			}
		end
	end
end

local function new()
	local ret = gobject({})
	gtable.crush(ret, desktop, true)

	ret._private = {}
	ret._private.cell_size = 100

	-- TODO fix
	--generate_grid()
	--scan_for_desktop_files_on_init(ret)
	--watch_desktop_directory(ret)

	return ret
end

if not instance then
	instance = new()
end
return instance
