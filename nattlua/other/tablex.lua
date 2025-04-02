local tablex = {}

do -- new
	local ok, new = pcall(require, "table.new")

	if ok then
		tablex.new = new
	else
		function tablex.new(size--[[#: number]], records--[[#: number]])
			return {}
		end
	end
end

do -- clear
	local ok, clear = pcall(require, "table.clear")

	if ok then
		tablex.clear = clear
	else
		function tablex.clear(t)
			for k, v in pairs(t) do
				t[k] = nil
			end
		end
	end
end

do -- copy (shallow)
	local ok, copy = pcall(require, "table.copy")

	if ok then
		tablex.copy = copy
	else
		function tablex.copy(tbl)
			local copy = {}

			for i = 1, #tbl do
				copy[i] = tbl[i]
			end

			return copy
		end
	end
end

return tablex
