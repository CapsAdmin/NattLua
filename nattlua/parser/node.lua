--[[# --ANALYZE
local type { Token } = import("~/nattlua/lexer/token.lua")]]

--[[#local type { Code } = import("~/nattlua/code.lua")]]

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
--[[#type META.@Self = {
	@Name = "Node",
	type = "expression" | "statement",
	_type = "expression" | "statement",
	kind = string,
	_kind = string,
	Type = string,
	id = number,
	Code = Code,
	tokens = Map<|string, false | Token | List<|Token|>|>,
	inferred_types = List<|any|>,
	inferred_types_done = Map<|any, any|>,
	environment = "typesystem" | "runtime",
	parent = false | self,
	code_start = number,
	code_stop = number,
	first_node = false | self,
	statements = false | List<|any|>,
	value = false | Token,
	lua_code = any,
	--
	scope = any,
	scopes = any,
	type_expression = any,
	identifier = any,
	first_node = any,
	environments = any,
	identifiers_typesystem = any,
	error_node = boolean,
	is_identifier = boolean,
	is_left_assignment = boolean,
	is_expression = boolean,
	is_statement = boolean,
}]]
--[[#type Node = META.@Self]]
local all_nodes = {
	["sub_statement_table_expression_value"] = function()
		return {
			is_statement = true,
			value_expression = false,
			type_expression = false,
			key_expression = false,
			spread = false,
			tokens = {
				["]"] = false,
				["="] = false,
				[":"] = false,
				["["] = false,
				["table"] = false,
			},
		}
	end,
	["sub_statement_table_index_value"] = function()
		return {
			is_statement = true,
			value_expression = false,
			spread = false,
			key = false,
			tokens = {
				["table"] = false,
			},
		}
	end,
	["sub_statement_table_key_value"] = function()
		return {
			is_statement = true,
			value_expression = false,
			type_expression = false,
			spread = false,
			tokens = {
				["{"] = false,
				["}"] = false,
				[":"] = false,
				["="] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_function"] = function()
		return {
			is_expression = true,
			return_types = false,
			statements = false,
			identifiers = false,
			environments_override = false,
			self_call = false,
			tokens = {
				["function"] = false,
				["end"] = false,
				["arguments)"] = false,
				["return:"] = false,
				["arguments("] = false,
				["table"] = false,
			},
		}
	end,
	["expression_analyzer_function"] = function()
		return {
			is_expression = true,
			return_types = false,
			statements = false,
			compiled_function = false,
			identifiers = false,
			environments_override = false,
			self_call = false,
			tokens = {
				["analyzer"] = false,
				["function"] = false,
				["arguments)"] = false,
				["table"] = false,
				["return:"] = false,
				["arguments("] = false,
				["end"] = false,
			},
		}
	end,
	["expression_type_function"] = function()
		return {
			is_expression = true,
			statements = false,
			identifiers = false,
			identifiers_typesystem = false,
			environments_override = false,
			self_call = false,
			return_types = false,
			tokens = {
				["function"] = false,
				["arguments)"] = false,
				["end"] = false,
				["arguments("] = false,
				["table"] = false,
			},
		}
	end,
	["expression_function_signature"] = function()
		return {
			is_expression = true,
			return_types = false,
			identifiers = false,
			tokens = {
				["="] = false,
				["arguments("] = false,
				["arguments)"] = false,
				[">"] = false,
				["return)"] = false,
				["function"] = false,
				[":"] = false,
				["table"] = false,
				["return("] = false,
			},
		}
	end,
	["expression_attribute_expression"] = function()
		return {
			is_expression = true,
			expression = false,
			tokens = {
				[")"] = false,
				["__attribute__"] = false,
				["("] = false,
				["table"] = false,
			},
		}
	end,
	["expression_tuple"] = function()
		return {
			is_expression = true,
			expressions = false,
			tokens = {
				[")"] = false,
				["("] = false,
				["table"] = false,
			},
		}
	end,
	["expression_vararg"] = function()
		return {
			is_expression = true,
			value = false,
			tokens = {
				["..."] = false,
				[":"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_empty_union"] = function()
		return {
			is_expression = true,
			tokens = {
				["|"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_error"] = function()
		return {
			is_expression = true,
			error_node = true,
			tokens = {},
		}
	end,
	["expression_type_table"] = function()
		return {
			is_expression = true,
			children = false,
			spread = false,
			tokens = {
				["}"] = false,
				["separators"] = false,
				["{"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_prefix_operator"] = function()
		return {
			is_expression = true,
			value = false,
			right = false,
			tokens = {
				["1"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_table"] = function()
		return {
			is_expression = true,
			is_array = false,
			children = false,
			spread = false,
			is_dictionary = false,
			tokens = {
				["}"] = false,
				["separators"] = false,
				["{"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_postfix_expression_index"] = function()
		return {
			is_expression = true,
			left = false,
			expression = false,
			is_left_assignment = false,
			tokens = {
				["]"] = false,
				["["] = false,
				["table"] = false,
			},
		}
	end,
	["expression_postfix_call"] = function()
		return {
			is_expression = true,
			RootStatement = false,
			key = false,
			import_expression = false,
			type_call = false,
			data = false,
			right = false,
			first_node = false,
			expressions_typesystem = false,
			require_expression = false,
			left = false,
			expressions = false,
			path = false,
			parser_call = false,
			tokens = {
				["call)"] = false,
				["call_typesystem("] = false,
				["call_typesystem)"] = false,
				["table"] = false,
				["call("] = false,
			},
		}
	end,
	["expression_value"] = function()
		return {
			is_expression = true,
			standalone_letter = false,
			attribute = false,
			is_identifier = false,
			type_expression = false,
			value = false,
			self_call = false,
			is_left_assignment = false,
			force_upvalue = false,
			tokens = {
				[">"] = false,
				["<"] = false,
				[":"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_union"] = function()
		return {
			is_expression = true,
			fields = false,
			tokens = {
				["{"] = false,
				["}"] = false,
				["union"] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_typedef"] = function()
		return {
			is_expression = true,
			decls = false,
			tokens = {
				["potential_identifier"] = false,
				["typedef"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_binary_operator"] = function()
		return {
			is_expression = true,
			is_left_assignment = false,
			value = false,
			left = false,
			right = false,
			tokens = {
				["table"] = false,
			},
		}
	end,
	["expression_dollar_sign"] = function()
		return {
			is_expression = true,
			tokens = {
				["$"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_lsx"] = function()
		return {
			is_expression = true,
			children = false,
			tag = false,
			props = false,
			tokens = {
				[">"] = false,
				["<"] = false,
				["/"] = false,
				["<2"] = false,
				["type2"] = false,
				[">2"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_postfix_operator"] = function()
		return {
			is_expression = true,
			left = false,
			value = false,
			tokens = {
				["table"] = false,
			},
		}
	end,
	["expression_table_spread"] = function()
		return {
			is_expression = true,
			expression = false,
			tokens = {
				["..."] = false,
				["table"] = false,
			},
		}
	end,
	["expression_enum_field"] = function()
		return {
			is_expression = true,
			expression = false,
			tokens = {
				["="] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_enum"] = function()
		return {
			is_expression = true,
			fields = false,
			tokens = {
				["enum"] = false,
				["{"] = false,
				["}"] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_struct"] = function()
		return {
			is_expression = true,
			fields = false,
			tokens = {
				["struct"] = false,
				["{"] = false,
				["}"] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["expression_c_declaration"] = function()
		return {
			is_expression = true,
			pointers = false,
			arguments = false,
			strings = false,
			expression = false,
			array_expression = false,
			modifiers = false,
			decls = false,
			default_expression = false,
			multi_values = false,
			bitfield_expression = false,
			tokens = {
				["identifier_("] = false,
				["identifier_)"] = false,
				["arguments_("] = false,
				["arguments_)"] = false,
				["..."] = false,
				["asm"] = false,
				["table"] = false,
				["asm_)"] = false,
				["asm_string"] = false,
				["asm_("] = false,
				[")"] = false,
				["potential_identifier"] = false,
				["identifier"] = false,
				["("] = false,
			},
		}
	end,
	["expression_array"] = function()
		return {
			is_expression = true,
			expression = false,
			tokens = {
				["]"] = false,
				["["] = false,
				["table"] = false,
			},
		}
	end,
	["statement_call_expression"] = function()
		return {
			is_statement = true,
			value = false,
			tokens = {
				["call)"] = false,
				["call_typesystem("] = false,
				["call_typesystem)"] = false,
				["table"] = false,
				["call("] = false,
			},
		}
	end,
	["statement_generic_for"] = function()
		return {
			is_statement = true,
			statements = false,
			expressions = false,
			identifiers = false,
			on_pop = false,
			tokens = {
				["for"] = false,
				["end"] = false,
				["in"] = false,
				["do"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_numeric_for"] = function()
		return {
			is_statement = true,
			statements = false,
			expressions = false,
			identifiers = false,
			on_pop = false,
			tokens = {
				["for"] = false,
				["="] = false,
				["end"] = false,
				["do"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_assignment"] = function()
		return {
			is_statement = true,
			left = false,
			right = false,
			tokens = {
				["type"] = false,
				["table"] = false,
				["="] = false,
			},
		}
	end,
	["statement_local_assignment"] = function()
		return {
			is_statement = true,
			left = false,
			right = false,
			tokens = {
				["="] = false,
				["type"] = false,
				["local"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_local_destructure_assignment"] = function()
		return {
			is_statement = true,
			default = false,
			default_comma = false,
			left = false,
			right = false,
			tokens = {
				["type"] = false,
				["{"] = false,
				["}"] = false,
				["="] = false,
				["local"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_if"] = function()
		return {
			is_statement = true,
			statements = false,
			expressions = false,
			tokens = {
				["then"] = false,
				["if/else/elseif"] = false,
				["end"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_break"] = function()
		return {
			is_statement = true,
			tokens = {
				["break"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_do"] = function()
		return {
			is_statement = true,
			statements = false,
			tokens = {
				["end"] = false,
				["do"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_shebang"] = function()
		return {
			is_statement = true,
			tokens = {
				["shebang"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_repeat"] = function()
		return {
			is_statement = true,
			statements = false,
			expression = false,
			on_pop = false,
			tokens = {
				["until"] = false,
				["repeat"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_return"] = function()
		return {
			is_statement = true,
			expressions = false,
			tokens = {
				["return"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_goto_label"] = function()
		return {
			is_statement = true,
			tokens = {
				["::"] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_while"] = function()
		return {
			is_statement = true,
			statements = false,
			expression = false,
			on_pop = false,
			tokens = {
				["while"] = false,
				["table"] = false,
				["do"] = false,
				["end"] = false,
			},
		}
	end,
	["statement_goto"] = function()
		return {
			is_statement = true,
			tokens = {
				["goto"] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_destructure_assignment"] = function()
		return {
			is_statement = true,
			default = false,
			left = false,
			right = false,
			default_comma = false,
			tokens = {
				["}"] = false,
				["table"] = false,
				["{"] = false,
				["="] = false,
			},
		}
	end,
	["statement_semicolon"] = function()
		return {
			is_statement = true,
			tokens = {
				[";"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_analyzer_debug_code"] = function()
		return {
			is_statement = true,
			lua_code = false,
			compiled_function = false,
			tokens = {
				["table"] = false,
			},
		}
	end,
	["statement_parser_debug_code"] = function()
		return {
			is_statement = true,
			lua_code = false,
			tokens = {
				["table"] = false,
			},
		}
	end,
	["statement_end_of_file"] = function()
		return {
			is_statement = true,
			tokens = {
				["end_of_file"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_error"] = function()
		return {
			is_statement = true,
			error_node = true,
			tokens = {},
		}
	end,
	["statement_root"] = function()
		return {
			is_statement = true,
			parser = false,
			code = false,
			imports = false,
			data_import = false,
			statements = false,
			imported = false,
			lexer_tokens = false,
			environments_override = false,
			tokens = {
				["shebang"] = false,
				["eof"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_local_analyzer_function"] = function()
		return {
			is_statement = true,
			return_types = false,
			statements = false,
			compiled_function = false,
			identifiers = false,
			environments_override = false,
			tokens = {
				["return:"] = false,
				["arguments("] = false,
				["arguments)"] = false,
				["analyzer"] = false,
				["function"] = false,
				["end"] = false,
				["local"] = false,
				["identifier"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_local_function"] = function()
		return {
			is_statement = true,
			return_types = false,
			statements = false,
			identifiers = false,
			environments_override = false,
			tokens = {
				["table"] = false,
				["arguments)"] = false,
				["function"] = false,
				["arguments("] = false,
				["local"] = false,
				["return:"] = false,
				["identifier"] = false,
				["end"] = false,
			},
		}
	end,
	["statement_function"] = function()
		return {
			is_statement = true,
			return_types = false,
			self_call = false,
			statements = false,
			expression = false,
			identifiers = false,
			environments_override = false,
			tokens = {
				["function"] = false,
				["end"] = false,
				["arguments)"] = false,
				["return:"] = false,
				["arguments("] = false,
				["table"] = false,
			},
		}
	end,
	["statement_local_type_function"] = function()
		return {
			is_statement = true,
			return_types = false,
			identifiers_typesystem = false,
			statements = false,
			identifiers = false,
			environments_override = false,
			tokens = {
				["arguments_typesystem("] = false,
				["arguments_typesystem)"] = false,
				["return:"] = false,
				["arguments("] = false,
				["arguments)"] = false,
				["function"] = false,
				["end"] = false,
				["identifier"] = false,
				["local"] = false,
				["table"] = false,
			},
		}
	end,
	["statement_analyzer_function"] = function()
		return {
			is_statement = true,
			return_types = false,
			self_call = false,
			statements = false,
			compiled_function = false,
			environments_override = false,
			expression = false,
			identifiers = false,
			tokens = {
				["^"] = false,
				["analyzer"] = false,
				["function"] = false,
				["table"] = false,
				["arguments)"] = false,
				["return:"] = false,
				["arguments("] = false,
				["end"] = false,
			},
		}
	end,
	["statement_type_function"] = function()
		return {
			is_statement = true,
			self_call = false,
			identifiers_typesystem = false,
			statements = false,
			expression = false,
			identifiers = false,
			environments_override = false,
			tokens = {
				["arguments)"] = false,
				["function"] = false,
				["arguments_typesystem("] = false,
				["arguments_typesystem)"] = false,
				["end"] = false,
				["arguments("] = false,
				["table"] = false,
			},
		}
	end,
}
--[[#local type NodeKind = keysof<|all_nodes|>]]

-- TODO, replace this with META.New_type_kind()
-- TODO, replace type-kind with .Type
function META.New(
	type--[[#: ref NodeKind]],
	environment--[[#: "typesystem" | "runtime"]],
	code--[[#: Code]],
	code_start--[[#: number]],
	code_stop--[[#: number]],
	parent--[[#: any]]
)
	local init = all_nodes[type]()

	if init.is_expression then
		init.is_statement = false
	else
		init.is_expression = false
	end

	init.Type = type
	init.environment = environment
	init.code_start = code_start
	init.code_stop = code_stop
	init.parent = parent
	init.Code = code
	init.inferred_types = {}
	init.inferred_types_done = {}
	--
	init.scope = false
	init.scopes = false
	init.type_expression = false
	init.identifier = false
	init.first_node = false
	--
	init.environments = false
	init.identifiers_typesystem = false
	init.error_node = false
	init.is_identifier = false
	init.is_left_assignment = false
	return setmetatable(init--[[# as META.@Self]], META)
end

function META:__tostring()
	local str = "[" .. self.Type

	if self.is_statement then
		local name = self.Code:GetName()

		if name:sub(-4) == ".lua" or name:sub(-5) == ".nlua" then
			local data = self.Code:SubPosToLineChar(self:GetStartStop())
			local name = name

			if name:sub(1, 1) == "@" then name = name:sub(2) end

			str = str .. " @ " .. name .. ":" .. data.line_start
		end
	elseif self.is_expression then
		if self.Type == "expression_postfix_call" and self.Code then
			local name = self.Code:GetName()

			if name and self.lua_code and (name:sub(-4) == ".lua" or name:sub(-5) == ".nlua") then
				local data = self.Code:SubPosToLineChar(self:GetStartStop())
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

META:IsSet("Unreachable", nil--[[# as boolean | nil]])

function META:Render(config)
	local emitter

	do
		-- we have to do this because nattlua.emitter is not yet typed
		-- so if it's hoisted the self/node.lua will fail
		if _G.IMPORTS--[[# as false]] then
			emitter = IMPORTS["nattlua.emitter.emitter"]()
		else
			--[[#£ parser.dont_hoist_next_import = true]]

			emitter = require("nattlua.emitter.emitter"--[[# as string]])
		end
	end

	local em = emitter.New(config or {preserve_whitespace = false, no_newlines = true})

	if self.is_expression then
		--[[#attest.expect_diagnostic<|"error", "mutate argument"|>]]
		em:EmitExpression(self)
	elseif self.is_statement then
		--[[#attest.expect_diagnostic<|"error", "mutate argument"|>]]
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
	if self.is_statement then return self end

	if self.parent then return (self.parent--[[# as any]]):GetStatement() end

	return self
end

function META:GetRoot()
	if self.parent then return (self.parent--[[# as any]]):GetRoot() end

	return self
end

function META:GetRootExpression()
	if self.parent and self.parent.is_expression then
		return (self.parent--[[# as any]]):GetRootExpression()
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

	if self.Type == "statement_if" then
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

local STRING_TYPE = {}
local NUMBER_TYPE = {}
local NAN_TYPE = {}
local ANY_TYPE = {}

function META:AssociateType(obj)
	do
		local t = obj.Type
		local hash = obj

		if hash.Type == "symbol" then
			hash = obj.Data
		elseif obj.Type == "string" then
			hash = obj.Data or STRING_TYPE
		elseif obj.Type == "number" then
			hash = obj.Data or NUMBER_TYPE

			if hash ~= hash then hash = NAN_TYPE end
		elseif obj.Type == "any" then
			hash = ANY_TYPE
		end

		if self.inferred_types_done[hash] then return end

		self.inferred_types_done[hash] = true
	end

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
	what--[[#: NodeKind]],
	out--[[#: ref mutable List<|Node|>]]
)--[[#: mutable List<|Node|>]]
	out = out or {}

	for _, child in ipairs(node:GetNodes()) do
		if child.Type == what then
			table.insert(out, child)
		elseif child:GetNodes() then
			(find_by_type--[[# as any]])(child, what, out)
		end
	end

	return out
end

function META:FindNodesByType(what--[[#: NodeKind]])
	return find_by_type(self, what, {})
end

--[[#type META.NodeKind = NodeKind]]
--[[#type META.Node = Node]]
--[[#type META.Nodes = all_nodes]]
return META
