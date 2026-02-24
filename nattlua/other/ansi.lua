--ANALYZE
local os = _G.os
local ansi = {}
local ESC = "\27["
-- Reset all attributes
ansi.reset = ESC .. "0m"
-- Base attributes
ansi.bold = ESC .. "1m"
ansi.dim = ESC .. "2m"
ansi.italic = ESC .. "3m"
-- Standard foreground colors
ansi.red = ESC .. "31m"
ansi.green = ESC .. "32m"
ansi.yellow = ESC .. "33m"
ansi.blue = ESC .. "34m"
ansi.magenta = ESC .. "35m"
ansi.cyan = ESC .. "36m"
ansi.white = ESC .. "37m"
-- Bright foreground colors
ansi.bright_black = ESC .. "90m" -- dark gray
ansi.bright_red = ESC .. "91m"
ansi.bright_green = ESC .. "92m"
ansi.bright_yellow = ESC .. "93m"
ansi.bright_blue = ESC .. "94m"
ansi.bright_magenta = ESC .. "95m"
ansi.bright_cyan = ESC .. "96m"
ansi.bright_white = ESC .. "97m"
-- Compound codes (bold + color)
ansi.bold_red = ESC .. "1;31m"
ansi.bold_yellow = ESC .. "1;33m"
ansi.bold_cyan = ESC .. "1;36m"
ansi.bold_bright_cyan = ESC .. "1;96m"

-- Returns the foreground color appropriate for a diagnostic severity.
-- severity: "error" | "warning" | "hint" | nil → defaults to error styling
function ansi.severity_color(severity--[[#: nil | string]])--[[#: string]]
	if severity == "warning" then
		return ansi.bold_yellow
	elseif severity == "hint" then
		return ansi.bold_cyan
	else
		-- "error" or nil/unknown → red
		return ansi.bold_red
	end
end

-- Wrap str in a color code followed by a reset.
function ansi.wrap(color--[[#: string]], str--[[#: string]])--[[#: string]]
	return color .. str .. ansi.reset
end

-- Returns true when ANSI output is likely supported.
-- Respects the NO_COLOR env-var convention (https://no-color.org/).
function ansi.is_supported()--[[#: boolean]]
	local no_color = os.getenv("NO_COLOR")

	if no_color ~= nil then return false end

	return true
end

-- Disable all ANSI codes (e.g. for plain-text / markdown output).
-- After calling this, wrap() returns its string argument unchanged.
function ansi.Disable()
	ansi.reset = ""
	ansi.bold = ""
	ansi.dim = ""
	ansi.italic = ""
	ansi.red = ""
	ansi.green = ""
	ansi.yellow = ""
	ansi.blue = ""
	ansi.magenta = ""
	ansi.cyan = ""
	ansi.white = ""
	ansi.bright_black = ""
	ansi.bright_red = ""
	ansi.bright_green = ""
	ansi.bright_yellow = ""
	ansi.bright_blue = ""
	ansi.bright_magenta = ""
	ansi.bright_cyan = ""
	ansi.bright_white = ""
	ansi.bold_red = ""
	ansi.bold_yellow = ""
	ansi.bold_cyan = ""
	ansi.bold_bright_cyan = ""
end

return ansi
