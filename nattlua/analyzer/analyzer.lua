local tostring = tostring
local error = error
local setmetatable = setmetatable
local ipairs = ipairs
require("nattlua.types.types").Initialize()
local META = {}
META.__index = META
META.OnInitialize = {}
require("nattlua.analyzer.base.base_analyzer")(META)
require("nattlua.analyzer.control_flow")(META)
require("nattlua.analyzer.mutations")(META)
require("nattlua.analyzer.operators.index").Index(META)
require("nattlua.analyzer.operators.newindex").NewIndex(META)
require("nattlua.analyzer.operators.call").Call(META)

do
	local AnalyzeAssignment = require("nattlua.analyzer.statements.assignment").AnalyzeAssignment
	local AnalyzeDestructureAssignment = require("nattlua.analyzer.statements.destructure_assignment").AnalyzeDestructureAssignment
	local AnalyzeFunction = require("nattlua.analyzer.statements.function").AnalyzeFunction
	local AnalyzeIf = require("nattlua.analyzer.statements.if").AnalyzeIf
	local AnalyzeDo = require("nattlua.analyzer.statements.do").AnalyzeDo
	local AnalyzeGenericFor = require("nattlua.analyzer.statements.generic_for").AnalyzeGenericFor
	local AnalyzeCall = require("nattlua.analyzer.statements.call_expression").AnalyzeCall
	local AnalyzeNumericFor = require("nattlua.analyzer.statements.numeric_for").AnalyzeNumericFor
	local AnalyzeBreak = require("nattlua.analyzer.statements.break").AnalyzeBreak
	local AnalyzeContinue = require("nattlua.analyzer.statements.continue").AnalyzeContinue
	local AnalyzeRepeat = require("nattlua.analyzer.statements.repeat").AnalyzeRepeat
	local AnalyzeReturn = require("nattlua.analyzer.statements.return").AnalyzeReturn
	local AnalyzeTypeCode = require("nattlua.analyzer.statements.type_code").AnalyzeTypeCode
	local AnalyzeWhile = require("nattlua.analyzer.statements.while").AnalyzeWhile

	function META:AnalyzeStatement(statement)
		self.current_statement = statement

		if statement.kind == "assignment" or statement.kind == "local_assignment" then
			AnalyzeAssignment(self, statement)
		elseif
			statement.kind == "destructure_assignment" or
			statement.kind == "local_destructure_assignment"
		then
			AnalyzeDestructureAssignment(self, statement)
		elseif
			statement.kind == "function" or
			statement.kind == "type_function" or
			statement.kind == "local_function" or
			statement.kind == "local_type_function" or
			statement.kind == "local_analyzer_function" or
			statement.kind == "analyzer_function"
		then
			AnalyzeFunction(self, statement)
		elseif statement.kind == "if" then
			AnalyzeIf(self, statement)
		elseif statement.kind == "while" then
			AnalyzeWhile(self, statement)
		elseif statement.kind == "do" then
			AnalyzeDo(self, statement)
		elseif statement.kind == "repeat" then
			AnalyzeRepeat(self, statement)
		elseif statement.kind == "return" then
			AnalyzeReturn(self, statement)
		elseif statement.kind == "break" then
			AnalyzeBreak(self, statement)
		elseif statement.kind == "continue" then
			AnalyzeContinue(self, statement)
		elseif statement.kind == "call_expression" then
			AnalyzeCall(self, statement)
		elseif statement.kind == "generic_for" then
			AnalyzeGenericFor(self, statement)
		elseif statement.kind == "numeric_for" then
			AnalyzeNumericFor(self, statement)
		elseif statement.kind == "type_code" then
			AnalyzeTypeCode(self, statement)
		elseif statement.kind == "import" then

		elseif
			statement.kind ~= "end_of_file" and
			statement.kind ~= "semicolon" and
			statement.kind ~= "shebang" and
			statement.kind ~= "goto_label" and
			statement.kind ~= "parser_code" and
			statement.kind ~= "goto"
		then
			self:FatalError("unhandled statement: " .. tostring(statement))
		end
	end
end

do
	local AnalyzeBinaryOperator = require("nattlua.analyzer.expressions.binary_operator").AnalyzeBinaryOperator
	local AnalyzePrefixOperator = require("nattlua.analyzer.expressions.prefix_operator").AnalyzePrefixOperator
	local AnalyzePostfixOperator = require("nattlua.analyzer.expressions.postfix_operator").AnalyzePostfixOperator
	local AnalyzePostfixCall = require("nattlua.analyzer.expressions.postfix_call").AnalyzePostfixCall
	local AnalyzePostfixIndex = require("nattlua.analyzer.expressions.postfix_index").AnalyzePostfixIndex
	local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
	local AnalyzeTable = require("nattlua.analyzer.expressions.table").AnalyzeTable
	local AnalyzeAtomicValue = require("nattlua.analyzer.expressions.atomic_value").AnalyzeAtomicValue
	local AnalyzeImport = require("nattlua.analyzer.expressions.import").AnalyzeImport
	local Union = require("nattlua.types.union").Union
	local Tuple = require("nattlua.types.tuple").Tuple

	function META:AnalyzeExpression(node, env)
		self.current_expression = node
		env = env or "runtime"

		if self:GetPreferTypesystem() then
			env = "typesystem"
		end

		if node.type_expression then
			if node.kind == "table" then
				local obj = AnalyzeTable(self, node, env)
				obj:SetContract(self:AnalyzeExpression(node.type_expression, "typesystem"))
				return obj
			end

			return self:AnalyzeExpression(node.type_expression, "typesystem")
		elseif node.kind == "value" then
			return AnalyzeAtomicValue(self, node, env)
		elseif node.kind == "function" or node.kind == "analyzer_function" or node.kind == "type_function" then
			return AnalyzeFunction(self, node, env)
		elseif node.kind == "table" or node.kind == "type_table" then
			return AnalyzeTable(self, node, env)
		elseif node.kind == "binary_operator" then
			return AnalyzeBinaryOperator(self, node, env)
		elseif node.kind == "prefix_operator" then
			return AnalyzePrefixOperator(self, node, env)
		elseif node.kind == "postfix_operator" then
			return AnalyzePostfixOperator(self, node, env)
		elseif node.kind == "postfix_expression_index" then
			return AnalyzePostfixIndex(self, node, env)
		elseif node.kind == "postfix_call" then
			return AnalyzePostfixCall(self, node, env)
		elseif node.kind == "import" then
			return AnalyzeImport(self, node, env)
		elseif node.kind == "empty_union" then
			return Union({}):SetNode(node)
		elseif node.kind == "tuple" then
			return Tuple(self:AnalyzeExpressions(node.expressions, env)):SetNode(node):SetUnpackable(true)
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
