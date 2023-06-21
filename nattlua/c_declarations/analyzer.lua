local class = require("nattlua.other.class")
local META = class.CreateTemplate("analyzer")

function META:WalkRoot(node)
	for _, node in ipairs(node.statements) do
		if node.kind == "c_declaration" then
			self:WalkCDeclaration(node)
		elseif node.kind == "typedef" then
			self:WalkTypedef(node)
		end
	end
end

local function handle_struct(self, node)
	local struct = {type = "struct", identifier = node.tokens["identifier"].value}
	local old = self.cdecl

	if node.fields then
		struct.fields = {}

		for _, field in ipairs(node.fields) do
			local t = {type = "root"}
			self.cdecl = t
			self:WalkCDeclaration_(field, nil)
			t.of.identifier = field.tokens["potential_identifier"].value
			table.insert(struct.fields, t.of)
		end
	end

	self.cdecl = old
	return struct
end

local function handle_enum(self, node)
	local struct = {type = "enum", fields = {}, identifier = node.tokens["identifier"].value}

	for _, field in ipairs(node.fields) do
		table.insert(struct.fields, {type = "enum_field", identifier = field.tokens["identifier"].value})
	end

	return struct
end

local function handle_modifiers(self, node)
	local modifiers = {}

	for k, v in ipairs(node.modifiers) do
		if v.kind == "struct" or v.kind == "union" then
			table.insert(modifiers, handle_struct(self, v))
		elseif v.kind == "enum" then
			table.insert(modifiers, handle_enum(self, v))
		else
			if not v.DONT_WRITE then table.insert(modifiers, v.value) end
		end
	end

	if modifiers[1] then
		self.cdecl.of = {
			type = "type",
			modifiers = modifiers,
		}
		self.cdecl = assert(self.cdecl.of)
	end
end

local function handle_array_expression(self, node)
	for k, v in ipairs(node.array_expression) do
		self.cdecl.of = {
			type = "array",
			size = v.expression:Render(),
		}
		self.cdecl = self.cdecl.of
	end
end

local function handle_function(self, node)
	local args = {}
	local old = self.cdecl

	for i, v in ipairs(node.arguments) do
		local t = {type = "root"}
		self.cdecl = t
		self:WalkCDeclaration_(v, nil)
		table.insert(args, t.of)
	end

	self.cdecl = old
	self.cdecl.of = {
		type = "function",
		args = args,
		rets = {type = "root"},
	}
	self.cdecl = assert(self.cdecl.of.rets)
end

local function handle_pointers(self, node)
	for k, v in ipairs(node.pointers) do
		local modifiers = {}

		for i = #v, 1, -1 do
			local v = v[i]

			if not v.DONT_WRITE then
				if v.value ~= "*" then table.insert(modifiers, v.value) end
			end
		end

		self.cdecl.of = {
			type = "pointer",
			modifiers = modifiers,
		}
		self.cdecl = assert(self.cdecl.of)
	end
end

function META:WalkCDeclaration_(node, walk_up)
	if node.array_expression then handle_array_expression(self, node) end

	if node.pointers then handle_pointers(self, node) end

	if node.arguments then handle_function(self, node) end

	if node.modifiers then handle_modifiers(self, node) end

	if not walk_up then return end

	if node.parent.kind == "c_declaration" then
		self:WalkCDeclaration_(node.parent, true)
	end
end

function META:WalkCDeclaration(node)
	local real_node = node

	while node.expression do -- find the inner most expression
		node = node.expression
	end

	self.cdecl = {type = "root", of = nil}
	local cdecl = self.cdecl
	self:WalkCDeclaration_(node, true, out)
	self.Callback(cdecl.of, real_node)
end

function META.New(ast, callback)
	local self = setmetatable({}, META)
	self.Callback = callback
	self:WalkRoot(ast)
	return self
end

return META