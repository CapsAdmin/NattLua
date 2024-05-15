local class = require("nattlua.other.class")
local META = class.CreateTemplate("analyzer")
local Table = require("nattlua.types.table").Table
local Tuple = require("nattlua.types.tuple").Tuple
local Function = require("nattlua.types.function").Function
local Number = require("nattlua.types.number").Number
local String = require("nattlua.types.string").String
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Nil = require("nattlua.types.symbol").Nil
local Boolean = require("nattlua.types.union").Boolean

function META:WalkRoot(node)
	for _, node in ipairs(node.statements) do
		if node.kind == "c_declaration" then
			self:WalkCDeclaration(node)
		elseif node.kind == "typedef" then
			self:WalkTypedef(node)
		end
	end
end

function META:WalkTypedef(node)
	for _, decl in ipairs(node.decls) do
		self:WalkCDeclaration(decl)
	end
end

local function handle_struct(self, node)
	local struct = {type = "struct"}

	if node.tokens["identifier"] then
		struct.identifier = node.tokens["identifier"].value
	end

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

local function cast(self, node)
	local env = self.env
	local analyzer = self.analyzer
	local typs = self.typs

	if node.type == "array" then
		return (
			env.FFIArray:Call(
				analyzer,
				Tuple({LNumber(tonumber(node.size) or math.huge), cast(self, assert(node.of))})
			):Unpack()
		)
	elseif node.type == "pointer" then
		return (env.FFIPointer:Call(analyzer, Tuple({cast(self, assert(node.of))})):Unpack())
	elseif node.type == "type" then
		for _, v in ipairs(node.modifiers) do
			if type(v) == "table" then
				if v.type == "struct" or v.type == "union" then
					local ident = v.identifier

					if not ident and #node.modifiers > 0 then
						ident = node.modifiers[#node.modifiers]
					end

					local tbl = typs:Get(LString(ident))

					if not tbl and v.fields then
						tbl = Table()

						for _, v in ipairs(v.fields) do
							tbl:Set(LString(ident), cast(self, v))
						end
					end

					if not tbl then
						local current = self.current_nodes[1]
						if current.ident == ident then
							-- recursion
							tbl = current.tbl
						end
					end

					return (tbl)
				elseif v.type == "enum" then
					-- using enum as type is the same as if it were an int
					return (Number())
				else
					error("unknown type " .. v.type)
				end
			end
		end
		
		local t = node.modifiers[1]

		if
			t == "double" or
			t == "float" or
			t == "int8_t" or
			t == "uint8_t" or
			t == "int16_t" or
			t == "uint16_t" or
			t == "int32_t" or
			t == "uint32_t" or
			t == "char" or
			t == "signed char" or
			t == "unsigned char" or
			t == "short" or
			t == "short int" or
			t == "signed short" or
			t == "signed short int" or
			t == "unsigned short" or
			t == "unsigned short int" or
			t == "int" or
			t == "signed" or
			t == "signed int" or
			t == "unsigned" or
			t == "unsigned int" or
			t == "long" or
			t == "long int" or
			t == "signed long" or
			t == "signed long int" or
			t == "unsigned long" or
			t == "unsigned long int" or
			t == "float" or
			t == "double" or
			t == "long double" or
			t == "size_t" or
			t == "intptr_t" or
			t == "uintptr_t"
		then
			return Number()
		elseif
			t == "int64_t" or
			t == "uint64_t" or
			t == "long long" or
			t == "long long int" or
			t == "signed long long" or
			t == "signed long long int" or
			t == "unsigned long long" or
			t == "unsigned long long int"
		then
			return Number()
		elseif t == "bool" or t == "_Bool" then
			return Boolean()
		elseif t == "void" then
			return Nil()
		elseif t == "va_list" then
			return Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
		end

		return (Number())
	elseif node.type == "function" then
		local args = {}
		local rets = {}

		for i, v in ipairs(node.args) do
			table.insert(args, cast(self, v))
		end

		return (Function(Tuple(args), Tuple({cast(self, assert(node.rets))})))
	elseif node.type == "root" then
		return (cast(self, assert(node.of)))
	else
		error("unknown type " .. node.type)
	end
end

local function cast_type(self, node, out)
	local typs = self.typs

	if node.type == "array" then
		cast_type(self, node.of, out)
	elseif node.type == "pointer" then
		cast_type(self, node.of, out)
	elseif node.type == "type" then
		for _, v in ipairs(node.modifiers) do
			if type(v) == "table" then
				if v.type == "struct" or v.type == "union" then
					local tbl

					if v.fields then
						tbl = Table()


						local ident = v.identifier

						if not ident and #node.modifiers > 0 then
							ident = node.modifiers[#node.modifiers]
						end

						self.current_nodes = self.current_nodes or {}
						table.insert(self.current_nodes, 1, {ident = ident, tbl = tbl})
						
						--tbl:Set(LString("__id"), LString(("%p"):format({})))
						for _, v in ipairs(v.fields) do
							tbl:Set(LString(v.identifier), cast(self, v))
						end

						table.remove(self.current_nodes, 1)

						table.insert(out, {identifier = ident, obj = tbl})
					else
						tbl = typs:Get(LString(v.identifier)) or Table()
						table.insert(out, {identifier = v.identifier, obj = tbl})
					end
				elseif v.type == "enum" then
					local tbl = Table()
					local i = 0

					for _, v in ipairs(v.fields) do
						tbl:Set(LString(v.identifier), LNumber(i))
						i = i + 1
					end

					table.insert(out, {identifier = v.identifier, obj = tbl})
				else
					error("unknown type " .. v.type)
				end
			end
		end
	elseif node.type == "function" then
		for i, v in ipairs(node.args) do
			cast_type(self, v, out)
		end

		cast_type(self, node.rets, out)
	elseif node.type == "root" then
		return cast_type(self, node.of, out)
	else
		error("unknown type " .. node.type)
	end
end

function META:AnalyzeRoot(ast)
	local vars = Table()
	local typs = Table()
	self.typs = typs
	self.Callback = function(node, real_node)
		local out = {}
		cast_type(self, node, out)

		for _, typedef in ipairs(out) do
			typs:Set(LString(assert(typedef.identifier)), typedef.obj)
		end

		local obj = cast(self, node)
		vars:Set(LString(real_node.tokens["potential_identifier"].value), obj)
	end
	self:WalkRoot(ast)
	return vars, typs
end

function META.New()
	local self = setmetatable({}, META)
	return self
end

return META