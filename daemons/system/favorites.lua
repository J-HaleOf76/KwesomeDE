-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2022 Kasper24
-------------------------------------------
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local helpers = require("helpers")
local string = string

local favorites = {}
local instance = nil

function favorites:add_favorite(client)
    self._private.favorites[client.class] = {}
    awful.spawn.easy_async(string.format("ps -p %d -o args=", client.pid), function(stdout)
        self._private.favorites[client.class] = stdout
        helpers.settings:set_value("favorite-apps", self._private.favorites)
    end)
end

function favorites:remove_favorite(client)
    self._private.favorites[client.class] = nil
    self:emit_signal(client.class .. "::removed")
    helpers.settings:set_value("favorite-apps", self._private.favorites)
end

function favorites:toggle_favorite(client)
    if self._private.favorites[client.class] == nil then
        self:add_favorite(client)
    else
        self:remove_favorite(client)
    end
end

function favorites:is_favorite(class)
    return self._private.favorites[class]
end

function favorites:get_favorites()
    return self._private.favorites
end

local function new()
    local ret = gobject {}
    gtable.crush(ret, favorites, true)

    ret._private = {}
    ret._private.favorites = helpers.settings:get_value("favorite-apps")

    return ret
end

if not instance then
    instance = new()
end
return instance
