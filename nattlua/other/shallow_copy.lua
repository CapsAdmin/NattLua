local function shallow_copy(tbl)
	local copy = {}

	for i = 1, #tbl do
		copy[i] = tbl[i]
	end

	return copy
end

return shallow_copy
