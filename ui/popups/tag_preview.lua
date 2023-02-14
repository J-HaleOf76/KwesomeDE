-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2022 Kasper24
-------------------------------------------
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gmatrix = require("gears.matrix")
local gtimer = require("gears.timer")
local wibox = require("wibox")
local beautiful = require("beautiful")
local widgets = require("ui.widgets")
local theme_daemon = require("daemons.system.theme")
local helpers = require("helpers")
local dpi = beautiful.xresources.apply_dpi
local collectgarbage = collectgarbage
local ipairs = ipairs
local capi = {
    client = client,
    tag = tag
}

local tag_preview = {}
local instance = nil

local function _get_widget_geometry(_hierarchy, widget)
    local width, height = _hierarchy:get_size()
    if _hierarchy:get_widget() == widget then
        -- Get the extents of this widget in the device space
        local x, y, w, h = gmatrix.transform_rectangle(_hierarchy:get_matrix_to_device(), 0, 0, width, height)
        return {
            x = x,
            y = y,
            width = w,
            height = h,
            hierarchy = _hierarchy
        }
    end

    for _, child in ipairs(_hierarchy:get_children()) do
        local ret = _get_widget_geometry(child, widget)
        if ret then
            return ret
        end
    end
end

local function get_widget_geometry(wibox, widget)
    return _get_widget_geometry(wibox._drawable._widget_hierarchy, widget)
end

local function save_tag_thumbnail(tag)
    if tag.selected == true then
        local screenshot = awful.screenshot {
            screen = awful.screen.focused()
        }
        screenshot:refresh()
        tag.thumbnail = screenshot.surface
    end
end

function tag_preview:show(t, args)
    args = args or {}

    args.coords = args.coords or self.coords
    args.wibox = args.wibox
    args.widget = args.widget
    args.offset = args.offset or {}

    if not args.coords and args.wibox and args.widget then
        args.coords = get_widget_geometry(args.wibox, args.widget)
        if args.offset.x ~= nil then
            args.coords.x = args.coords.x + args.offset.x
        end
        if args.offset.y ~= nil then
            args.coords.y = args.coords.y + args.offset.y
        end

        self.widget.x = args.coords.x
        self.widget.y = args.coords.y
    end

    save_tag_thumbnail(t)

    local widget = wibox.widget {
        widget = wibox.widget.imagebox,
        forced_width = dpi(300),
        forced_height = dpi(150),
        horizontal_fit_policy = "fit",
        vertical_fit_policy = "fit",
        image = t.thumbnail or theme_daemon:get_wallpaper_surface()
    }

    self.widget.widget = widget
    self.widget.visible = true
end

function tag_preview:hide()
    self.widget.visible = false
    self.widget.widget = nil
    collectgarbage("collect")
end

function tag_preview:toggle(t, args)
    if self.widget.visible == true then
        self:hide()
    else
        self:show(t, args)
    end
end

local function new(args)
    args = args or {}

    local ret = gobject {}
    ret._private = {}

    gtable.crush(ret, tag_preview)
    gtable.crush(ret, args)

    ret.widget = widgets.popup {
        type = 'dropdown_menu',
        visible = false,
        ontop = true,
        shape = helpers.ui.rrect(),
        bg = beautiful.colors.background,
        widget = wibox.container.background -- A dummy widget to make awful.popup not scream
    }

    capi.client.connect_signal("property::fullscreen", function(c)
        if c.fullscreen then
            ret:hide()
        end
    end)

    capi.client.connect_signal("focus", function(c)
        if c.fullscreen then
            ret:hide()
        end
    end)

    capi.tag.connect_signal("property::selected", function(t)
        -- Wait a little bit so it won't screenshot the previous tag
        gtimer {
            timeout = 0.4,
            autostart = true,
            call_now = false,
            single_shot = true,
            callback = function()
                save_tag_thumbnail(t)
            end
        }
    end)

    return ret
end

if not instance then
    instance = new()
end
return instance
