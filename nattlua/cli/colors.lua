local use_colors = not os.getenv("NO_COLOR")

if jit and jit.os == "Windows" then
	pcall(os.execute, "")

	if not os.getenv("ANSICON") and not os.getenv("ConEmuANSI") then
		use_colors = false
	end
end

local colors = {
	reset = "0",
	bold = "1",
	dim = "2",
	italic = "3",
	underline = "4",
	blink = "5",
	reverse = "7",
	-- Foreground colors
	black = "30",
	red = "31",
	green = "32",
	yellow = "33",
	blue = "34",
	magenta = "35",
	cyan = "36",
	white = "37",
	-- Background colors
	bg_black = "40",
	bg_red = "41",
	bg_green = "42",
	bg_yellow = "43",
	bg_blue = "44",
	bg_magenta = "45",
	bg_cyan = "46",
	bg_white = "47",
}

local function wrap_color(code)
	return function(text)
		if use_colors then
			return string.format("\27[%sm%s\27[0m", code, text)
		else
			return text
		end
	end
end

for name, code in pairs(colors) do
	if type(code) == "string" then
		colors[name] = wrap_color(code)
	end
end

function colors.Disable()
	use_colors = false
end

function colors.set_enabled(b)
	use_colors = b
end

colors.SetEnabled = colors.set_enabled

function colors.IsEnabled()
	return use_colors
end

return colors
