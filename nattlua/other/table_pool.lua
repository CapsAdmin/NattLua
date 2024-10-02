local pairs = _G.pairs
local table_new = require("nattlua.other.table_new")
local table_clear = require("nattlua.other.table_clear")
return function(alloc--[[#: ref (function=()>({[string] = any}))]], size--[[#: number]])
	local records = 0

	for _, _ in pairs(alloc()) do
		records = records + 1
	end

	local pool = table_new(size, 0)--[[# as {[number] = nil | return_type<|alloc|>[1]}]]
	local i = 1

	for i = 1, size do
		pool[i] = table_new(0, records)
	end

	local function refill()
		i = 1
		table_clear(pool)

		for i = 1, size do
			pool[i] = table_new(0, records)
		end
	end

	return function()
		local tbl = pool[i]

		if not tbl then
			refill()
			tbl = pool[i]--[[# as return_type<|alloc|>[1] ]]
		end

		i = i + 1
		return tbl
	end
end
