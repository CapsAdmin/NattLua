local tostring = tostring
local error = error
local setmetatable = setmetatable
local ipairs = ipairs
local math = require("math")
local Tuple = require("nattlua.types.tuple").Tuple
local Any = require("nattlua.types.any").Any
local Table = require("nattlua.types.table").Table
local Number = require("nattlua.types.number").Number
local String = require("nattlua.types.string").String
local Symbol = require("nattlua.types.symbol").Symbol
local Boolean = require("nattlua.types.symbol").Boolean
local Function = require("nattlua.types.function").Function
local Nil = require("nattlua.types.symbol").Nil
require("nattlua.types.types").Initialize()
local META = {}
META.__index = META
META.OnInitialize = {}
require("nattlua.analyzer.base.base_analyzer")(META)
require("nattlua.analyzer.control_flow")(META)
require("nattlua.analyzer.operators.index")(META)
require("nattlua.analyzer.operators.newindex")(META)
require("nattlua.analyzer.operators.call")(META)

function META:AnalyzeRootStatement(statement, ...)
	local argument_tuple = ... and Tuple({...}) or Tuple({...}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
	self:CreateAndPushFunctionScope()
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

return function(config)
	config = config or {}
	local self = setmetatable({config = config}, META)

	for _, func in ipairs(META.OnInitialize) do
		func(self)
	end

	return self
end
