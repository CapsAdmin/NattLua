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
local all_nodes = {
	sub_statement = {
		["table_expression_value"] = function()
			return {
				value_expression = false,
				type_expression = false,
				key_expression = false,
				tokens = {
					["]"] = false,
					["="] = false,
					[":"] = false,
					["["] = false,
					["table"] = false,
				},
			}
		end,
		["table_index_value"] = function()
			return {
				value_expression = false,
				spread = false,
				key = false,
				tokens = {
					["table"] = false,
				},
			}
		end,
		["table_key_value"] = function()
			return {
				value_expression = false,
				type_expression = false,
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
	},
	expression = {
		["attribute_expression"] = function()
			return {
				expression = false,
				tokens = {
					[")"] = false,
					["__attribute__"] = false,
					["("] = false,
					["table"] = false,
				},
			}
		end,
		["tuple"] = function()
			return {
				expressions = false,
				tokens = {
					[")"] = false,
					["("] = false,
					["table"] = false,
				},
			}
		end,
		["vararg"] = function()
			return {
				value = false,
				tokens = {
					["..."] = false,
					[":"] = false,
					["table"] = false,
				},
			}
		end,
		["empty_union"] = function()
			return {
				tokens = {
					["|"] = false,
					["table"] = false,
				},
			}
		end,
		["type_table"] = function()
			return {
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
		["prefix_operator"] = function()
			return {
				value = false,
				right = false,
				tokens = {
					["1"] = false,
					["table"] = false,
				},
			}
		end,
		["table"] = function()
			return {
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
		["postfix_expression_index"] = function()
			return {
				left = false,
				expression = false,
				tokens = {
					["]"] = false,
					["["] = false,
					["table"] = false,
				},
			}
		end,
		["function"] = function()
			return {
				return_types = false,
				statements = false,
				identifiers = false,
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
		["postfix_call"] = function()
			return {
				RootStatement = false,
				key = false,
				import_expression = false,
				type_call = false,
				data = false,
				right = false,
				first_node = false,
				expressions_typesystem = false,
				left = false,
				expressions = false,
				path = false,
				tokens = {
					["call)"] = false,
					["call_typesystem("] = false,
					["call_typesystem)"] = false,
					["table"] = false,
					["call("] = false,
				},
			}
		end,
		["value"] = function()
			return {
				standalone_letter = false,
				attribute = false,
				is_identifier = false,
				type_expression = false,
				value = false,
				tokens = {
					[">"] = false,
					["<"] = false,
					[":"] = false,
					["table"] = false,
				},
			}
		end,
		["union"] = function()
			return {
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
		["typedef"] = function()
			return {
				decls = false,
				tokens = {
					["potential_identifier"] = false,
					["typedef"] = false,
					["table"] = false,
				},
			}
		end,
		["analyzer_function"] = function()
			return {
				return_types = false,
				statements = false,
				compiled_function = false,
				identifiers = false,
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
		["type_function"] = function()
			return {
				statements = false,
				identifiers = false,
				tokens = {
					["function"] = false,
					["arguments)"] = false,
					["end"] = false,
					["arguments("] = false,
					["table"] = false,
				},
			}
		end,
		["binary_operator"] = function()
			return {
				is_left_assignment = false,
				value = false,
				left = false,
				right = false,
				tokens = {
					["table"] = false,
				},
			}
		end,
		["dollar_sign"] = function()
			return {
				tokens = {
					["$"] = false,
					["table"] = false,
				},
			}
		end,
		["lsx"] = function()
			return {
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
		["postfix_operator"] = function()
			return {
				left = false,
				value = false,
				tokens = {
					["table"] = false,
				},
			}
		end,
		["table_spread"] = function()
			return {
				expression = false,
				tokens = {
					["..."] = false,
					["table"] = false,
				},
			}
		end,
		["enum_field"] = function()
			return {
				expression = false,
				tokens = {
					["="] = false,
					["identifier"] = false,
					["table"] = false,
				},
			}
		end,
		["enum"] = function()
			return {
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
		["struct"] = function()
			return {
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
		["function_signature"] = function()
			return {
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
		["c_declaration"] = function()
			return {
				pointers = false,
				arguments = false,
				strings = false,
				expression = false,
				array_expression = false,
				modifiers = false,
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
		["array"] = function()
			return {
				expression = false,
				tokens = {
					["]"] = false,
					["["] = false,
					["table"] = false,
				},
			}
		end,
	},
	statement = {
		["call_expression"] = function()
			return {
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
		["generic_for"] = function()
			return {
				statements = false,
				expressions = false,
				identifiers = false,
				tokens = {
					["for"] = false,
					["end"] = false,
					["in"] = false,
					["do"] = false,
					["table"] = false,
				},
			}
		end,
		["numeric_for"] = function()
			return {
				statements = false,
				expressions = false,
				identifiers = false,
				tokens = {
					["for"] = false,
					["="] = false,
					["end"] = false,
					["do"] = false,
					["table"] = false,
				},
			}
		end,
		["assignment"] = function()
			return {
				left = false,
				right = false,
				tokens = {
					["type"] = false,
					["table"] = false,
					["="] = false,
				},
			}
		end,
		["local_assignment"] = function()
			return {
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
		["local_destructure_assignment"] = function()
			return {
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
		["local_function"] = function()
			return {
				return_types = false,
				statements = false,
				identifiers = false,
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
		["function"] = function()
			return {
				return_types = false,
				self_call = false,
				statements = false,
				expression = false,
				identifiers = false,
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
		["local_type_function"] = function()
			return {
				return_types = false,
				identifiers_typesystem = false,
				statements = false,
				identifiers = false,
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
		["if"] = function()
			return {
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
		["break"] = function()
			return {
				tokens = {
					["break"] = false,
					["table"] = false,
				},
			}
		end,
		["do"] = function()
			return {
				statements = false,
				tokens = {
					["end"] = false,
					["do"] = false,
					["table"] = false,
				},
			}
		end,
		["shebang"] = function()
			return {
				tokens = {
					["shebang"] = false,
					["table"] = false,
				},
			}
		end,
		["analyzer_function"] = function()
			return {
				return_types = false,
				self_call = false,
				statements = false,
				compiled_function = false,
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
		["type_function"] = function()
			return {
				self_call = false,
				identifiers_typesystem = false,
				statements = false,
				expression = false,
				identifiers = false,
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
		["repeat"] = function()
			return {
				statements = false,
				expression = false,
				tokens = {
					["until"] = false,
					["repeat"] = false,
					["table"] = false,
				},
			}
		end,
		["return"] = function()
			return {
				expressions = false,
				tokens = {
					["return"] = false,
					["table"] = false,
				},
			}
		end,
		["goto_label"] = function()
			return {
				tokens = {
					["::"] = false,
					["identifier"] = false,
					["table"] = false,
				},
			}
		end,
		["while"] = function()
			return {
				statements = false,
				expression = false,
				tokens = {
					["while"] = false,
					["table"] = false,
					["do"] = false,
					["end"] = false,
				},
			}
		end,
		["goto"] = function()
			return {
				tokens = {
					["goto"] = false,
					["identifier"] = false,
					["table"] = false,
				},
			}
		end,
		["destructure_assignment"] = function()
			return {
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
		["local_analyzer_function"] = function()
			return {
				return_types = false,
				statements = false,
				compiled_function = false,
				identifiers = false,
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
		["semicolon"] = function()
			return {
				tokens = {
					[";"] = false,
					["table"] = false,
				},
			}
		end,
		["analyzer_debug_code"] = function()
			return {
				lua_code = false,
				compiled_function = false,
				tokens = {
					["table"] = false,
				},
			}
		end,
		["parser_debug_code"] = function()
			return {
				lua_code = false,
				tokens = {
					["table"] = false,
				},
			}
		end,
		["end_of_file"] = function()
			return {
				tokens = {
					["end_of_file"] = false,
					["table"] = false,
				},
			}
		end,
		["root"] = function()
			return {
				imports = false,
				data_import = false,
				statements = false,
				imported = false,
				tokens = {
					["shebang"] = false,
					["eof"] = false,
					["table"] = false,
				},
			}
		end,
	},
}

function META.New(
	type--[[#: "expression" | "statement"]],
	kind--[[#: StatementKind | ExpressionKind]],
	environment--[[#: any]],
	code--[[#: any]],
	code_start--[[#: number]],
	code_stop--[[#: number]],
	parent--[[#: any]]
)--[[#: Node]]
	local init = all_nodes[type][kind]()
	init.type = type
	init.kind = kind
	init.environment = environment
	init.code_start = code_start
	init.code_stop = code_stop
	init.parent = parent
	init.Code = code
	init.inferred_types = {}
	return setmetatable(init--[[# as META.@Self]], META)
end

function META:__tostring()
	local str = "[" .. self.type .. " - " .. self.kind

	if self.type == "statement" then
		local name = self.Code:GetName()

		if name:sub(-4) == ".lua" or name:sub(-5) == ".nlua" then
			local data = self.Code:SubPosToLineChar(self:GetStartStop())
			local name = name

			if name:sub(1, 1) == "@" then name = name:sub(2) end

			str = str .. " @ " .. name .. ":" .. data.line_start
		end
	elseif self.type == "expression" then
		if self.kind == "postfix_call" and self.Code then
			local name = self.Code:GetName()

			if name and lua_code and (name:sub(-4) == ".lua" or name:sub(-5) == ".nlua") then
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
