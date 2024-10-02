--[[#local type { Token } = import("~/nattlua/token.lua")]]

--[[#local type { ExpressionKind, StatementKind, Node } = import("~/nattlua/parser/nodes.nlua")]]

--[[#local type NodeType = "expression" | "statement"]]
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = _G.table
local formating = require("nattlua.other.formating")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("node")
--[[#type META.@Name = "Node"]]
--[[#type META.@Self = Node]]

function META.New(
	type--[[#: "expression" | "statement"]],
	kind--[[#: StatementKind | ExpressionKind]],
	environment--[[#: any]],
	code--[[#: any]],
	code_start--[[#: number]],
	code_stop--[[#: number]],
	parent--[[#: any]]
)--[[#: Node]]
	local init = {
		type = type,
		kind = kind,
		environment = environment,
		Code = code,
		code_start = code_start,
		code_stop = code_stop,
		parent = parent,
		tokens = {},
		inferred_types = {},
		--
		is_identifier = false,
		value = false,
		standalone_letter = false,
		value = false,
		first_node = false,
		right = false,
		expressions = false,
		statements = false,
		left = false,
		children = false,
		import_expression = false,
		path = false,
		imported = false,
		key = false,
		data_import = false,
		key_expression = false,
		value_expression = false,
		spread = false,
		identifiers = false,
		return_types = false,
		expression = false,
		force_upvalue = false,
		identifier = false,
		identifiers_typesystem = false,
		type_call = false,
		self_call = false,
		type_expression = false,
		attribute = false,
		scope = false,
		environments = false,
		environments_override = false,
		require_expression = false,
		expressions_typesystem = false,
		compiled_function = false,
		is_array = false,
		is_left_assignment = false,
		on_pop = false,
		parser_call = false,
		lexer_tokens = false,
		parser = false,
		code = false,
		RootStatement = false,
		imports = false,
		is_dictionary = false,
		lua_code = false,
		data = false,
		is_whitespace = false,
		arguments = false,
		pointers = false,
		modifiers = false,
		props = false,
		default = false,
		default_comma = false,
		--ffi
		strings = false,
		array_expression = false,
		fields = false,
		multi_values = false,
		bitfield_expression = false,
		default_expression = false,
		decls = false,
		tag = false,
	}
	return setmetatable(init--[[# as META.@Self]], META)
end

function META:__tostring()
	local str = "[" .. self.type .. " - " .. self.kind

	if self.type == "statement" then
		local lua_code = self.Code:GetString()
		local name = self.Code:GetName()

		if name:sub(-4) == ".lua" or name:sub(-5) == ".nlua" then
			local data = formating.SubPositionToLinePosition(lua_code, self:GetStartStop())
			local name = name

			if name:sub(1, 1) == "@" then name = name:sub(2) end

			str = str .. " @ " .. name .. ":" .. data.line_start
		end
	elseif self.type == "expression" then
		if self.kind == "postfix_call" and self.Code then
			local lua_code = self.Code:GetString()
			local name = self.Code:GetName()

			if name and lua_code and (name:sub(-4) == ".lua" or name:sub(-5) == ".nlua") then
				local data = formating.SubPositionToLinePosition(lua_code, self:GetStartStop())
				local name = name

				if name:sub(1, 1) == "@" then name = name:sub(2) end

				str = str .. " @ " .. name .. ":" .. data.line_start
			end
		else
			if self.value and type(self.value.value) == "string" then
				str = str .. " - " .. formating.QuoteToken(self.value.value)
			end
		end
	end

	return str .. "]"
end

function META:Render(config)
	local emitter

	do
		--[[#-- we have to do this because nattlua.emitter is not yet typed
		-- so if it's hoisted the self/nodes.nlua will fail
		attest.expect_diagnostic<|"warning", "always false"|>]]
		--[[#attest.expect_diagnostic<|"warning", "always true"|>]]

		if _G.IMPORTS--[[# as false]] then
			emitter = IMPORTS["nattlua.emitter"]()
		else
			--[[#£ parser.dont_hoist_next_import = true]]

			emitter = require("nattlua.emitter"--[[# as string]])
		end
	end

	local em = emitter.New(config or {preserve_whitespace = false, no_newlines = true})

	if self.type == "expression" then
		em:EmitExpression(self)
	elseif self.type == "statement" then
		em:EmitStatement(self)
	end

	return em:Concat()
end

function META:GetSourcePath()
	if self.Code then
		local path = self.Code:GetName()

		if path:sub(1, 1) == "@" then path = path:sub(2) end

		return path
	end
end

function META:GetStartStop()
	return self.code_start, self.code_stop
end

function META:GetStatement()
	if self.type == "statement" then return self end

	if self.parent then return self.parent:GetStatement() end

	return self
end

function META:GetRoot()
	if self.parent then return self.parent:GetRoot() end

	return self
end

function META:GetRootExpression()
	if self.parent and self.parent.type == "expression" then
		return self.parent:GetRootExpression()
	end

	return self
end

function META:GetLength()
	local start, stop = self:GetStartStop()

	if self.first_node then
		local start2, stop2 = self.first_node:GetStartStop()

		if start2 < start then start = start2 end

		if stop2 > stop then stop = stop2 end
	end

	return stop - start
end

function META:GetNodes()--[[#: List<|any|>]]
	local statements = self.statements--[[# as any]]

	if self.kind == "if" then
		local flat--[[#: List<|any|>]] = {}

		for _, statements in ipairs(assert(statements)) do
			for _, v in ipairs(statements) do
				table.insert(flat, v)
			end
		end

		return flat
	end

	return statements or {}
end

function META:HasNodes()
	return self.statements ~= nil
end

function META:AssociateType(obj)
	self.inferred_types[#self.inferred_types + 1] = obj
end

function META:GetAssociatedTypes()
	return self.inferred_types
end

function META:GetLastAssociatedType()
	return self.inferred_types[#self.inferred_types]
end

local function find_by_type(
	node--[[#: META.@Self]],
	what--[[#: StatementKind | ExpressionKind]],
	out--[[#: List<|META.@Name|>]]
)
	out = out or {}

	for _, child in ipairs(node:GetNodes()) do
		if child.kind == what then
			table.insert(out, child)
		elseif child:GetNodes() then
			find_by_type(child, what, out)
		end
	end

	return out
end

function META:FindNodesByType(what--[[#: StatementKind | ExpressionKind]])
	return find_by_type(self, what, {})
end

return META
