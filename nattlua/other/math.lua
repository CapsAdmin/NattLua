--ANALYZE
local mathx = {}

function mathx.clamp(num--[[#: number]], min--[[#: number]], max--[[#: number]])
	return math.min(math.max(num, min), max)
end

function mathx.round(num--[[#: number]], idp--[[#: number | nil]])
	if idp and idp > 0 then
		local mult = 10 ^ idp
		return math.floor(num * mult + 0.5) / mult
	end

	return math.floor(num + 0.5)
end

return mathx