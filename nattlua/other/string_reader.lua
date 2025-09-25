local ffi = require("ffi")
local bit_bor = require("bit").bor

local function build_tree1(items, is_lexer)
	if is_lexer then error("Lexer mode not supported in build_tree1") end

	if false--[[# as true]] then return _--[[# as any]] end

	local longest = 0
	local map = {}

	table.sort(items, function(a, b)
		return #a > #b
	end)

	for _, str in ipairs(items) do
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

local function build_tree2(items, is_lexer, lowercase)
	if false--[[# as true]] then return _--[[# as any]] end

	local longest = 0
	local max_nodes = 1 -- root
	table.sort(items, function(a, b)
		return #a > #b
	end)

	for _, str in ipairs(items) do
		max_nodes = max_nodes + #str
		longest = math.max(longest, #str)
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

	for _, str in ipairs(items) do
		local current_node = 0

		for i = 1, #str do
			local byte_val = str:byte(i)

			if lowercase then byte_val = bit_bor(byte_val, 32) end

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
		string_storage[current_node + 1] = str
	end

	if is_lexer then
		if lowercase then
			return function(lexer)
				local node_index = 0

				for i = 0, longest - 1 do
					local b = lexer:PeekByteOffset(i)

					if lowercase then b = bit_bor(b, 32) end

					local child = nodes[node_index].children[b]

					if child == 0 then break end

					node_index = child
				end

				return nodes[node_index].end_marker == 1 and string_storage[node_index + 1] or nil
			end
		end

		return function(lexer)
			local node_index = 0

			for i = 0, longest - 1 do
				local b = lexer:PeekByteOffset(i)
				local child = nodes[node_index].children[b]

				if child == 0 then break end

				node_index = child
			end

			return nodes[node_index].end_marker == 1 and string_storage[node_index + 1] or nil
		end
	end

	return function(token)
		local token_length = token:GetLength()

		if token_length > longest then return nil end

		if token_length == 1 then
			local child = nodes[0].children[token:GetByte(0)]

			if child == 0 then return nil end

			return nodes[child].end_marker == 1 and string_storage[child + 1] or nil
		end

		local node_index = 0

		for i = 0, token_length - 1 do
			local child = nodes[node_index].children[token:GetByte(i)]

			if child == 0 then return nil end

			node_index = child
		end

		return nodes[node_index].end_marker == 1 and string_storage[node_index + 1] or nil
	end
end

if jit then build_tree = build_tree2 else build_tree = build_tree1 end

return build_tree
