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
	local AnalyzeAnalyzerDebugCode = require("nattlua.analyzer.statements.analyzer_debug_code").AnalyzeAnalyzerDebugCode
	local AnalyzeWhile = require("nattlua.analyzer.statements.while").AnalyzeWhile

	function META:AnalyzeStatement(node)
		self.current_statement = node


		self:PushAnalyzerEnvironment(node.environment or "runtime")

		if node.kind == "assignment" or node.kind == "local_assignment" then
			AnalyzeAssignment(self, node)
		elseif
			node.kind == "destructure_assignment" or
			node.kind == "local_destructure_assignment"
		then
			AnalyzeDestructureAssignment(self, node)
		elseif
			node.kind == "function" or
			node.kind == "type_function" or
			node.kind == "local_function" or
			node.kind == "local_type_function" or
			node.kind == "local_analyzer_function" or
			node.kind == "analyzer_function"
		then
			AnalyzeFunction(self, node)
		elseif node.kind == "if" then
			AnalyzeIf(self, node)
		elseif node.kind == "while" then
			AnalyzeWhile(self, node)
		elseif node.kind == "do" then
			AnalyzeDo(self, node)
		elseif node.kind == "repeat" then
			AnalyzeRepeat(self, node)
		elseif node.kind == "return" then
			AnalyzeReturn(self, node)
		elseif node.kind == "break" then
			AnalyzeBreak(self, node)
		elseif node.kind == "continue" then
			AnalyzeContinue(self, node)
		elseif node.kind == "call_expression" then
			AnalyzeCall(self, node)
		elseif node.kind == "generic_for" then
			AnalyzeGenericFor(self, node)
		elseif node.kind == "numeric_for" then
			AnalyzeNumericFor(self, node)
		elseif node.kind == "analyzer_debug_code" then
			AnalyzeAnalyzerDebugCode(self, node)
		elseif node.kind == "import" then

		elseif
			node.kind ~= "end_of_file" and
			node.kind ~= "semicolon" and
			node.kind ~= "shebang" and
			node.kind ~= "goto_label" and
			node.kind ~= "parser_debug_code" and
			node.kind ~= "goto"
		then
			self:FatalError("unhandled statement: " .. tostring(node))
		end


		self:PopAnalyzerEnvironment()
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
	local AnalyzeTuple = require("nattlua.analyzer.expressions.tuple").AnalyzeTuple
	local AnalyzeFunctionSignature = require("nattlua.analyzer.expressions.function_signature").AnalyzeFunctionSignature
	local Union = require("nattlua.types.union").Union

	function META:AnalyzeExpression(node)
		self.current_expression = node

		if node.type_expression then

			if node.kind == "table" then
				local obj = AnalyzeTable(self, node)
				self:PushAnalyzerEnvironment("typesystem")
				obj:SetContract(self:AnalyzeExpression(node.type_expression))
				self:PopAnalyzerEnvironment()
				return obj
			end

			self:PushAnalyzerEnvironment("typesystem")
			local obj = self:AnalyzeExpression(node.type_expression)
			self:PopAnalyzerEnvironment()

			return obj
		elseif node.kind == "value" then
			return AnalyzeAtomicValue(self, node)
		elseif node.kind == "function" or node.kind == "analyzer_function" or node.kind == "type_function" then
			return AnalyzeFunction(self, node)
		elseif node.kind == "table" or node.kind == "type_table" then
			return AnalyzeTable(self, node)
		elseif node.kind == "binary_operator" then
			return AnalyzeBinaryOperator(self, node)
		elseif node.kind == "prefix_operator" then
			return AnalyzePrefixOperator(self, node)
		elseif node.kind == "postfix_operator" then
			return AnalyzePostfixOperator(self, node)
		elseif node.kind == "postfix_expression_index" then
			return AnalyzePostfixIndex(self, node)
		elseif node.kind == "postfix_call" then
			return AnalyzePostfixCall(self, node)
		elseif node.kind == "import" then
			return AnalyzeImport(self, node)
		elseif node.kind == "empty_union" then
			return Union({}):SetNode(node)
		elseif node.kind == "tuple" then
			return AnalyzeTuple(self, node)
		elseif node.kind == "function_signature" then
			return AnalyzeFunctionSignature(self, node)
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
