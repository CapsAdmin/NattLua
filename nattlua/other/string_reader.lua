

-- Fixed version - the key issue was not respecting token length in the loop
local function build_tree1(
	items--[[#: List<|string|> | List<|BinaryOperatorInfo|> | List<|OperatorFunctionInfo|>]]
)
	if false--[[# as true]] then return _--[[# as any]] end

	local return_value = type(items[1]) == "table"
	local longest = 0
	local map = {}
	local lookup = {}

	if return_value then
		for i, v in ipairs(items) do
			lookup[v.op] = v
		end
	else
		for i, v in ipairs(items) do
			lookup[v] = v
		end
	end

	if return_value then
		table.sort(items, function(a, b)
			return #a.op > #b.op
		end)
	else
		table.sort(items, function(a, b)
			return #a > #b
		end)
	end

	for _, item in ipairs(items) do
		local str

		if return_value then str = item.op else str = item end

		if #str > longest then longest = #str end

		str = str--[[# as string]]
		local node = map

		for i = 1, #str do
			local b = str:byte(i)
			node[b] = node[b] or {}
			node = node[b]

			if i == #str then
				if return_value then node.END = item else node.END = item end
			end
		end
	end

	return function(token)
		if token.value then return lookup[token.value] end

		local token_length = token:GetLength()

		if token_length > longest then return nil end

		local node = map

		for i = 0, token_length - 1 do
			node = node[token:GetByte(i)]

			if not node then return nil end
		end

		return node.END
	end
end

local function build_tree2(
	items--[[#: List<|string|> | List<|BinaryOperatorInfo|> | List<|OperatorFunctionInfo|>]]
)
	if false--[[# as true]] then return _--[[# as any]] end

	local ffi = require("ffi")
	local return_value = type(items[1]) == "table"
	local longest = 0
	local max_nodes = 1 -- root
	local lookup = {}

	if return_value then
		for i, v in ipairs(items) do
			lookup[v.op] = v
		end
	else
		for i, v in ipairs(items) do
			lookup[v] = v
		end
	end

	if return_value then
		table.sort(items, function(a, b)
			return #a.op > #b.op
		end)

		for _, str in ipairs(items) do
			max_nodes = max_nodes + #str.op
			longest = math.max(longest, #str.op)
		end
	else
		table.sort(items, function(a, b)
			return #a > #b
		end)

		for _, str in ipairs(items) do
			max_nodes = max_nodes + #str
			longest = math.max(longest, #str)
		end
	end

	local node_type = ffi.typeof([[
		struct {
			uint8_t children[256];
			uint8_t end_marker;
		}
	]])
	local node_array_type = ffi.typeof("$[?]", node_type)
	local nodes = ffi.new(node_array_type, max_nodes)
	local string_storage = {}
	local node_count = 1

	for i = 0, 255 do
		nodes[0].children[i] = 0
	end

	nodes[0].end_marker = 0

	for _, item in ipairs(items) do
		local current_node = 0

		if return_value then str = item.op else str = item end

		for i = 1, #str do
			local byte_val = str:byte(i)
			local child_node = nodes[current_node].children[byte_val]

			if child_node == 0 then
				child_node = node_count
				node_count = node_count + 1

				for j = 0, 255 do
					nodes[child_node].children[j] = 0
				end

				nodes[child_node].end_marker = 0
				nodes[current_node].children[byte_val] = child_node
			end

			current_node = child_node
		end

		nodes[current_node].end_marker = 1
		string_storage[current_node] = item
	end

	return function(token)
		local token_length = token:GetLength()

		if token_length > longest then return nil end

		local node_index = 0

		if token_length == 1 then
			local child = nodes[0].children[token:GetByte(0)]

			if child == 0 then return nil end

			return nodes[child].end_marker == 1 and string_storage[child] or nil
		end

		for i = 0, token_length - 1 do
			local child = nodes[node_index].children[token:GetByte(i)]

			if child == 0 then return nil end

			node_index = child
		end

		return nodes[node_index].end_marker == 1 and string_storage[node_index] or nil
	end
end

if jit then build_tree = build_tree2 else build_tree = build_tree1 end

return build_tree