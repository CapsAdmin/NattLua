local tostring = tostring
local error = error
local setmetatable = setmetatable
local ipairs = ipairs
local types = require("nattlua.types.types")
local math = require("math")
types.Initialize()
local META = {}
META.__index = META
META.OnInitialize = {}
require("nattlua.analyzer.base.base_analyzer")(META)
require("nattlua.analyzer.control_flow")(META)
require("nattlua.analyzer.operators.index")(META)
require("nattlua.analyzer.operators.newindex")(META)
require("nattlua.analyzer.operators.call")(META)

function META:AnalyzeRootStatement(statement, ...)
	local argument_tuple = ... and types.Tuple({...}) or types.Tuple({...}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
	self:CreateAndPushFunctionScope(statement)
	self:PushEnvironment(statement, nil, "runtime")
	self:PushEnvironment(statement, nil, "typesystem")
	self:CreateLocalValue("...", argument_tuple, "runtime")
	local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(statement)
	self:PopEnvironment("runtime")
	self:PopEnvironment("typesystem")
	self:PopScope()
	return analyzed_return
end

do
	local assignment = require("nattlua.analyzer.statements.assignment")
	local destructure_assignment = require("nattlua.analyzer.statements.destructure_assignment")
	local _function = require("nattlua.analyzer.statements.function")
	local _if = require("nattlua.analyzer.statements.if")
	local _do = require("nattlua.analyzer.statements.do")
	local generic_for = require("nattlua.analyzer.statements.generic_for")
	local call_expression = require("nattlua.analyzer.statements.call_expression")
	local numeric_for = require("nattlua.analyzer.statements.numeric_for")
	local _break = require("nattlua.analyzer.statements.break")
	local _continue = require("nattlua.analyzer.statements.continue")
	local _repeat = require("nattlua.analyzer.statements.repeat")
	local _return = require("nattlua.analyzer.statements.return")
	local type_code = require("nattlua.analyzer.statements.type_code")
	local _while = require("nattlua.analyzer.statements.while")

	function META:AnalyzeStatement(statement)
		self.current_statement = statement

		if statement.kind == "assignment" or statement.kind == "local_assignment" then
			assignment(self, statement)
		elseif
			statement.kind == "destructure_assignment" or
			statement.kind == "local_destructure_assignment"
		then
			destructure_assignment(self, statement)
		elseif
			statement.kind == "function" or
			statement.kind == "generics_type_function" or
			statement.kind == "local_function" or
			statement.kind == "local_generics_type_function" or
			statement.kind == "local_type_function" or
			statement.kind == "type_function"
		then
			_function(self, statement)
		elseif statement.kind == "if" then
			_if(self, statement)
		elseif statement.kind == "while" then
			_while(self, statement)
		elseif statement.kind == "do" then
			_do(self, statement)
		elseif statement.kind == "repeat" then
			_repeat(self, statement)
		elseif statement.kind == "return" then
			_return(self, statement)
		elseif statement.kind == "break" then
			_break(self, statement)
		elseif statement.kind == "continue" then
			_continue(self, statement)
		elseif statement.kind == "call_expression" then
			call_expression(self, statement)
		elseif statement.kind == "generic_for" then
			generic_for(self, statement)
		elseif statement.kind == "numeric_for" then
			numeric_for(self, statement)
		elseif statement.kind == "type_code" then
			type_code(self, statement)
		elseif statement.kind == "import" then

		elseif
			statement.kind ~= "end_of_file" and
			statement.kind ~= "semicolon" and
			statement.kind ~= "shebang" and
			statement.kind ~= "goto_label" and
			statement.kind ~= "goto"
		then
			self:FatalError("unhandled statement: " .. tostring(statement))
		end
	end
end

do
	local binary_operator = require("nattlua.analyzer.expressions.binary_operator")
	local prefix_operator = require("nattlua.analyzer.expressions.prefix_operator")
	local postfix_operator = require("nattlua.analyzer.expressions.postfix_operator")
	local postfix_call = require("nattlua.analyzer.expressions.postfix_call")
	local postfix_expression_index = require("nattlua.analyzer.expressions.postfix_index")
	local _function = require("nattlua.analyzer.expressions.function")
	local table = require("nattlua.analyzer.expressions.table")
	local atomic_value = require("nattlua.analyzer.expressions.atomic_value")
	local type_list = require("nattlua.analyzer.expressions.list")
	local _import = require("nattlua.analyzer.expressions.import")

	function META:AnalyzeExpression(node, env)
		self.current_expression = node

		if not node then
			error("node is nil", 2)
		end

		if node.type ~= "expression" then
			error("node is not an expression", 2)
		end

		env = env or "runtime"

		if self:GetPreferTypesystem() then
			env = "typesystem"
		end

		if node.explicit_type then
			if node.kind == "table" then
				local obj = table(self, node, env)
				obj:SetContract(self:AnalyzeExpression(node.explicit_type, "typesystem"))
				return obj
			end

			return self:AnalyzeExpression(node.explicit_type, "typesystem")
		elseif node.kind == "value" then
			return atomic_value(self, node, env)
		elseif node.kind == "function" or node.kind == "type_function" then
			return _function(self, node, env)
		elseif node.kind == "table" or node.kind == "type_table" then
			return table(self, node, env)
		elseif node.kind == "type_list" then
			return type_list(self, node, env)
		elseif node.kind == "binary_operator" then
			return binary_operator(self, node, env)
		elseif node.kind == "prefix_operator" then
			return prefix_operator(self, node, env)
		elseif node.kind == "postfix_operator" then
			return postfix_operator(self, node, env)
		elseif node.kind == "postfix_expression_index" then
			return postfix_expression_index(self, node, env)
		elseif node.kind == "postfix_call" then
			return postfix_call(self, node, env)
		elseif node.kind == "import" then
			return _import(self, node, env)
		else
			self:FatalError("unhandled expression " .. node.kind)
		end
	end
end

function META:NewType(node, type, data, literal)
	local obj

	if type == "table" then
		obj = self:Assert(node, types.Table(data))
		obj.creation_scope = self:GetScope()
	elseif type == "list" then
		obj = self:Assert(node, types.List(data))
	elseif type == "..." then
		obj = self:Assert(node, types.Tuple(data or {types.Any()}))
		obj:SetRepeat(math.huge)
	elseif type == "number" then
		obj = self:Assert(node, types.Number(data):SetLiteral(literal))
	elseif type == "string" then
		obj = self:Assert(node, types.String(data):SetLiteral(literal))
	elseif type == "boolean" then
		if literal then
			obj = types.Symbol(data)
		else
			obj = types.Boolean()
		end
	elseif type == "nil" then
		obj = self:Assert(node, types.Symbol(nil))
	elseif type == "any" then
		obj = self:Assert(node, types.Any())
	elseif type == "function" then
		obj = self:Assert(node, types.Function(data))
		obj:SetNode(node)

		if node.statements then
			obj.function_body_node = node
		end
	end

	if not obj then
		error("NYI: " .. type)
	end

	obj:SetNode(obj:GetNode() or node)
	obj:GetNode().inferred_type = obj
	return obj
end

return function(config)
	config = config or {}
	local self = setmetatable({config = config}, META)

	for _, func in ipairs(META.OnInitialize) do
		func(self)
	end

	return self
end
