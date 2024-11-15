local wibox = require("wibox")
local swidget = require("ui.widgets.slider")
local bwidget = require("ui.widgets.background")
local tiwidget = require("ui.widgets.text_input")
local beautiful = require("beautiful")
local library = require("library")
local dpi = beautiful.xresources.apply_dpi
local tostring = tostring
local tonumber = tonumber

local slider_text_input = {
    mt = {}
}

local function new(args)
	args = args or {}

	args.spacing = args.spacing or dpi(20)
	args.value = args.value or 0

	args.forced_width = args.slider_width
	args.forced_height = args.slider_height
	local slider = swidget(args)

	local pattern = "numbers_one_decimal"
	if args.round then
		pattern = "round_numbers"
	end

	local text_input = wibox.widget {
		widget = tiwidget,
		forced_width = args.text_input_width or dpi(80),
		forced_height = args.text_input_height or dpi(40),
		pattern = pattern,
		initial = tostring(slider:get_value()),
		selection_bg = args.selection_bg or beautiful.colors.random_accent_color(),
		widget_template = wibox.widget {
			widget = bwidget,
			shape = library.ui.rrect(),
			bg = beautiful.colors.surface,
			{
				widget = wibox.container.margin,
				margins = dpi(5),
				{
					widget = wibox.widget.textbox,
					halign = "center",
					id = "text_role"
				}
			}
		}
	}

	local widget = wibox.widget {
		layout = wibox.layout.fixed.horizontal,
		spacing = args.spacing,
		slider,
		text_input
	}

	function widget:set_value(val)
		slider:set_value(val)
		text_input:set_text(val)
	end

	function widget:set_maximum(maximum)
        slider:set_maximum(maximum)
	end

	function widget:get_text_input()
		return text_input
	end

	text_input:connect_signal("property::text", function(self, text)
		local value = tonumber(text)

		if value == nil then
			return
		end

		-- Don't the text_input to show values like '01', '02' etc
		if value > 0 and text:sub(1, 1) == "0" then
			text_input:set_text(tostring(value), true)
		end
	end)

	text_input:connect_signal("unfocus", function(self, context, text)
		local value = tonumber(text)

		if value == slider:get_value() or value == nil then
			return
		end

		if value > args.maximum then
			text_input:set_text(tostring(args.maximum))
			slider:set_value(args.maximum)
			widget:emit_signal('property::value', args.maximum)
		elseif value < args.minimum then
			text_input:set_text(tostring(args.minimum))
			slider:set_value(args.minimum)
			widget:emit_signal('property::value', args.minimum)
		else
			slider:set_value(value)
			widget:emit_signal('property::value', value)
		end
	end)

	slider:connect_signal("property::value", function(self, value)
		text_input:set_text(tostring(value))
        widget:emit_signal('property::value', value)
    end)

	return widget
end

function slider_text_input.mt:__call(...)
    return new(...)
end

return setmetatable(slider_text_input, slider_text_input.mt)
