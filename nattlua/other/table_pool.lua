local ok, table_new = pcall(require, "table.new")

if not ok then
	table_new = function()
		return {}
	end
end

return function(alloc--[[#: (function(): {[string] = any})]], size--[[#: nil | number]])
	local records = 0

	for k, v in pairs(alloc()) do
		records = records + 1
	end

	local i
	local pool = table_new(size, records)

	local function refill()
		i = 1

		for i = 1, size do
			pool[i] = alloc()
		end
	end

	refill()
	return function()
		local tbl = pool[i]

		if not tbl then
			refill()
			tbl = pool[i]
		end

		i = i + 1
		return tbl
	end
end
