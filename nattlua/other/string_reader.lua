local bit_bor = require("nattlua.other.bit").bor
local has_ffi, ffi = pcall(require, "ffi")

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

	-- Use FFI if available, otherwise use tables
	if has_ffi and jit then
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
	else
		-- Table-based fallback when FFI is not available
		local nodes = {}
		local string_storage = {}
		local node_count = 1
		nodes[0] = {children = {}, end_marker = false}

		for _, str in ipairs(items) do
			local current_node = 0

			for i = 1, #str do
				local byte_val = str:byte(i)

				if lowercase then byte_val = bit_bor(byte_val, 32) end

				local child_node = nodes[current_node].children[byte_val]

				if not child_node then
					child_node = node_count
					node_count = node_count + 1
					nodes[child_node] = {children = {}, end_marker = false}
					nodes[current_node].children[byte_val] = child_node
				end

				current_node = child_node
			end

			nodes[current_node].end_marker = true
			string_storage[current_node] = str
		end

		if is_lexer then
			if lowercase then
				return function(lexer)
					local node_index = 0

					for i = 0, longest - 1 do
						local b = lexer:PeekByteOffset(i)

						if lowercase then b = bit_bor(b, 32) end

						local child = nodes[node_index].children[b]

						if not child then break end

						node_index = child
					end

					return nodes[node_index].end_marker and string_storage[node_index] or nil
				end
			end

			return function(lexer)
				local node_index = 0

				for i = 0, longest - 1 do
					local b = lexer:PeekByteOffset(i)
					local child = nodes[node_index].children[b]

					if not child then break end

					node_index = child
				end

				return nodes[node_index].end_marker and string_storage[node_index] or nil
			end
		end

		return function(token)
			local token_length = token:GetLength()

			if token_length > longest then return nil end

			if token_length == 1 then
				local child = nodes[0].children[token:GetByte(0)]

				if not child then return nil end

				return nodes[child].end_marker and string_storage[child] or nil
			end

			local node_index = 0

			for i = 0, token_length - 1 do
				local child = nodes[node_index].children[token:GetByte(i)]

				if not child then return nil end

				node_index = child
			end

			return nodes[node_index].end_marker and string_storage[node_index] or nil
		end
	end
end

return build_tree2
