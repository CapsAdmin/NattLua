local stringx = {}

function stringx.split(self--[[#: string]], separator--[[#: string]])
	local tbl = {}
	local current_pos--[[#: number]] = 1

	for i = 1, #self do
		local start_pos, end_pos = self:find(separator, current_pos, true)

		if not start_pos or not end_pos then break end

		tbl[i] = self:sub(current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end

	if current_pos > 1 then
		tbl[#tbl + 1] = self:sub(current_pos)
	else
		tbl[1] = self
	end

	return tbl
end

function stringx.trim(self--[[#: string]])
	local char = "%s*"
	local _, start = self:find(char, 0)
	local end_start, end_stop = self:reverse():find(char, 0)

	if start and end_start and end_stop then
		return self:sub(start + 1, (end_start - end_stop) - 2)
	elseif start then
		return self:sub(start + 1)
	elseif end_start and end_stop then
		return self:sub(0, (end_start - end_stop) - 2)
	end

	return self
end

function stringx.pad_left(str--[[#: string]], len--[[#: number]], char--[[#: string]])
	if #str < len + 1 then return char:rep(len - #str + 1) .. str end

	return str
end

function stringx.length_split(str, len)
	if #str > len then
		local tbl = {}
		local max = math.floor(#str / len)

		for i = 0, max do
			local left = i * len + 1
			local right = (i * len) + len
			local res = str:sub(left, right)

			if res ~= "" then table.insert(tbl, res) end
		end

		return tbl
	end

	return {str}
end

return stringx