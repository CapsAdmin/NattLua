-- this sort of unpacks and normalizes the C declaration AST to make it easier to work with
local walk_cdecl

local function handle_struct(state, node)
	local struct = {type = node.kind}

	if node.tokens["identifier"] then
		struct.identifier = node.tokens["identifier"].value
	end

	local old = state.cdecl

	if node.fields then
		struct.fields = {}

		for _, field in ipairs(node.fields) do
			local _, t = walk_cdecl(state, field)
			t.of.identifier = field.tokens["potential_identifier"] and
				field.tokens["potential_identifier"].value or
				nil
			table.insert(struct.fields, t.of)
		end
	end

	state.cdecl = old
	return struct
end

local function handle_enum(state, node)
	local struct = {
		type = "enum",
		fields = {},
		identifier = node.tokens["identifier"] and node.tokens["identifier"].value,
	}

	if node.fields then
		for _, field in ipairs(node.fields) do
			table.insert(struct.fields, {type = "enum_field", identifier = field.tokens["identifier"].value})
		end
	end

	return struct
end

local function handle_modifiers(state, node)
	local modifiers = {}

	for k, v in ipairs(node.modifiers) do
		if v.kind == "struct" or v.kind == "union" then
			table.insert(modifiers, handle_struct(state, v))
		elseif v.kind == "enum" then
			table.insert(modifiers, handle_enum(state, v))
		elseif v.kind == "dollar_sign" then
			table.insert(modifiers, "$")
		else
			table.insert(modifiers, v.value)
		end
	end

	if modifiers[1] then
		state.cdecl.of = {
			type = "type",
			modifiers = modifiers,
		}
		state.cdecl = assert(state.cdecl.of)
	end
end

local function handle_array_expression(state, node)
	for k, v in ipairs(node.array_expression) do
		state.cdecl.of = {
			type = "array",
			size = v.expression:Render(),
		}
		state.cdecl = state.cdecl.of
	end
end

local function handle_function(state, node)
	local args = {}
	local old = state.cdecl

	for i, v in ipairs(node.arguments) do
		v.parent = {type = "root"}
		local _, cdecl = walk_cdecl(state, v, nil)
		table.insert(args, cdecl.of)
	end

	state.cdecl = old
	state.cdecl.of = {
		type = "function",
		args = args,
		rets = {type = "root"},
	}
	state.cdecl = assert(state.cdecl.of.rets)
end

local function handle_pointers(state, node)
	for k, v in ipairs(node.pointers) do
		local modifiers = {}

		for i = #v, 1, -1 do
			local v = v[i]

			if v.value ~= "*" then table.insert(modifiers, v.value) end
		end

		state.cdecl.of = {
			type = "pointer",
			modifiers = modifiers,
		}
		state.cdecl = assert(state.cdecl.of)
	end
end

function walk_cdecl(state, node)
	local real_node = node

	while node.expression do -- find the inner most expression
		node = node.expression
	end

	state.cdecl = {type = "root", of = nil}
	local cdecl = state.cdecl

	while true do
		if node.array_expression then handle_array_expression(state, node) end

		if node.pointers then handle_pointers(state, node) end

		if node.arguments then handle_function(state, node) end

		if node.modifiers then handle_modifiers(state, node) end

		if node.tokens["..."] and node.type == "expression" then
			state.cdecl.of = {
				type = "va_list",
			}
			state.cdecl = assert(state.cdecl.of)
		end

		if node.parent.kind ~= "c_declaration" then break end

		node = node.parent
	end

	return node, cdecl, real_node
end

local function walk_cdeclarations(node, callback)
	local state = {}

	for _, node in ipairs(node.statements) do
		if node.kind == "c_declaration" then
			local node, cdecl, real_node = walk_cdecl(state, node)
			callback(cdecl.of, real_node, false)
		elseif node.kind == "typedef" then
			for _, node in ipairs(node.decls) do
				local node, cdecl, real_node = walk_cdecl(state, node)
				callback(cdecl.of, real_node, true)
			end
		end
	end
end

return walk_cdeclarations
