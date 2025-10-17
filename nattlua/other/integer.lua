
local strip_integer = (
		not jit and
		(
			_VERSION == "Lua 5.1" or
			_VERSION == "Lua 5.2" or
			_VERSION == "Lua 5.3" or
			_VERSION == "Lua 5.4"
		)
	)--[[# as boolean]]

local function string_to_integer(str--[[#: string]])--[[#: number]]
	if strip_integer then
		str = str:lower():sub(-3)

		if str == "ull" then
			str = str:sub(1, -4)
		elseif str:sub(-2) == "ll" then
			str = str:sub(1, -3)
		end
	end

	return assert(loadstring("return " .. str))()
end

return string_to_integer