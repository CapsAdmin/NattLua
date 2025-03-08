local class = require("nattlua.other.class")
local tostring = tostring
local error = error
local setmetatable = setmetatable
local ipairs = ipairs
require("nattlua.types.types").Initialize()
local META = class.CreateTemplate("analyzer")
META.OnInitialize = {}
require("nattlua.other.context_mixin")(META)
require("nattlua.analyzer.base.base_analyzer")(META)
require("nattlua.analyzer.control_flow")(META)
require("nattlua.analyzer.mutation_tracking")(META)
require("nattlua.analyzer.operators.index").Index(META)
require("nattlua.analyzer.operators.newindex").NewIndex(META)
require("nattlua.analyzer.operators.call").Call(META)

do
	local AnalyzeDestructureAssignment = require("nattlua.analyzer.statements.destructure_assignment").AnalyzeDestructureAssignment
	local AnalyzeIf = require("nattlua.analyzer.statements.if").AnalyzeIf
	local AnalyzeGenericFor = require("nattlua.analyzer.statements.generic_for").AnalyzeGenericFor
	local AnalyzeNumericFor = require("nattlua.analyzer.statements.numeric_for").AnalyzeNumericFor
	local AnalyzeWhile = require("nattlua.analyzer.statements.while").AnalyzeWhile
	local AnalyzeAssignment = require("nattlua.analyzer.statements.assignment").AnalyzeAssignment
	local ConstString = require("nattlua.types.string").ConstString
	local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction

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
			node.kind == "local_function" or
			node.kind == "local_analyzer_function" or
			node.kind == "local_type_function"
		then
			self:PushAnalyzerEnvironment(node.kind == "local_function" and "runtime" or "typesystem")
			self:CreateLocalValue(node.tokens["identifier"].value, AnalyzeFunction(self, node))
			self:PopAnalyzerEnvironment()
		elseif
			node.kind == "function" or
			node.kind == "analyzer_function" or
			node.kind == "type_function"
		then
			local key = node.expression
			self:PushAnalyzerEnvironment(node.kind == "function" and "runtime" or "typesystem")

			if key.kind == "binary_operator" then
				local obj = self:AnalyzeExpression(key.left)
				local key = self:AnalyzeExpression(key.right)
				local val = AnalyzeFunction(self, node)
				self:NewIndexOperator(obj, key, val)
			else
				self.current_expression = key
				local key = ConstString(key.value.value)
				local val = AnalyzeFunction(self, node)
				self:SetLocalOrGlobalValue(key, val)
			end

			self:PopAnalyzerEnvironment()
		elseif node.kind == "if" then
			AnalyzeIf(self, node)
		elseif node.kind == "while" then
			AnalyzeWhile(self, node)
		elseif node.kind == "do" then
			self:CreateAndPushScope()
			self:AnalyzeStatements(node.statements)
			self:PopScope()
		elseif node.kind == "repeat" then
			self:CreateAndPushScope()
			self:AnalyzeStatements(node.statements)
			self:PopScope()
		elseif node.kind == "return" then
			local ret = self:AnalyzeExpressions(node.expressions)
			self:Return(node, ret)
		elseif node.kind == "break" then
			self:Break()
		elseif node.kind == "continue" then
			self._continue_ = true
		elseif node.kind == "call_expression" then
			self:AnalyzeExpression(node.value)
		elseif node.kind == "generic_for" then
			AnalyzeGenericFor(self, node)
		elseif node.kind == "numeric_for" then
			AnalyzeNumericFor(self, node)
		elseif node.kind == "analyzer_debug_code" then
			local code = node.lua_code.value.value:sub(3)
			self:CallLuaTypeFunction(node.compiled_function, self:GetScope())
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

		node.scope = self:GetScope()
		self:PopAnalyzerEnvironment()
	end
end

do
	local Binary = require("nattlua.analyzer.operators.binary").Binary
	local AnalyzePostfixCall = require("nattlua.analyzer.expressions.postfix_call").AnalyzePostfixCall
	local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
	local AnalyzeTable = require("nattlua.analyzer.expressions.table").AnalyzeTable
	local AnalyzeAtomicValue = require("nattlua.analyzer.expressions.atomic_value").AnalyzeAtomicValue
	local AnalyzeLSX = require("nattlua.analyzer.expressions.lsx").AnalyzeLSX
	local Union = require("nattlua.types.union").Union
	local Tuple = require("nattlua.types.tuple").Tuple
	local VarArg = require("nattlua.types.tuple").VarArg
	local Prefix = require("nattlua.analyzer.operators.prefix").Prefix
	local Node = require("nattlua.parser.node")

	function META:AnalyzeRuntimeExpression(node)
		self.current_expression = node

		if node.kind == "value" then
			return AnalyzeAtomicValue(self, node)
		elseif node.kind == "vararg" then
			return VarArg(self:AnalyzeExpression(node.value))
		elseif
			node.kind == "function" or
			node.kind == "analyzer_function" or
			node.kind == "type_function" or
			node.kind == "function_signature"
		then
			return AnalyzeFunction(self, node)
		elseif node.kind == "table" or node.kind == "type_table" then
			return AnalyzeTable(self, node)
		elseif node.kind == "binary_operator" then
			return self:AssertWithNode(node, Binary(self, node))
		elseif node.kind == "prefix_operator" then
			if node.value.value == "not" then
				self.inverted_index_tracking = not self.inverted_index_tracking
			end

			local r = self:AnalyzeExpression(node.right)

			if node.value.value == "not" then self.inverted_index_tracking = false end

			self.current_expression = node
			return self:Assert(Prefix(self, node, r))
		elseif node.kind == "postfix_operator" then
			if node.value.value == "++" then
				local r = self:AnalyzeExpression(node.left)
				return Binary(self, setmetatable({value = {value = "+"}}, Node), r, r)
			end
		elseif node.kind == "postfix_expression_index" then
			if self:IsTypesystem() then
				return self:Assert(
					self:IndexOperator(self:AnalyzeExpression(node.left), self:AnalyzeExpression(node.expression))
				)
			else
				return self:Assert(
					self:IndexOperator(
						self:AnalyzeExpression(node.left):GetFirstValue(),
						self:AnalyzeExpression(node.expression):GetFirstValue()
					)
				)
			end
		elseif node.kind == "postfix_call" then
			return AnalyzePostfixCall(self, node)
		elseif node.kind == "empty_union" then
			return Union()
		elseif node.kind == "tuple" then
			local tup = Tuple():SetUnpackable(true)
			self:PushCurrentType(tup, "tuple")
			tup:SetTable(self:AnalyzeExpressions(node.expressions))
			self:PopCurrentType("tuple")
			return tup
		elseif node.kind == "lsx" then
			return AnalyzeLSX(self, node)
		else
			self:FatalError("unhandled expression " .. node.kind)
		end
	end

	function META:AnalyzeTypeExpression(node, parent_obj)
		self:PushAnalyzerEnvironment("typesystem")
		local obj = self:AnalyzeExpression(node)
		self:PopAnalyzerEnvironment()

		if obj.Type == "table" then
			if parent_obj.Type == "table" then
				parent_obj:SetContract(obj)
				return parent_obj
			elseif parent_obj.Type == "tuple" and parent_obj:HasOneValue() then
				local first = parent_obj:GetData()[1]

				if first.Type == "table" then
					first:SetContract(obj)
					return parent_obj
				end
			end
		end

		return obj
	end

	function META:AnalyzeExpression(node)
		local obj, err = self:AnalyzeRuntimeExpression(node)

		if node.type_expression then
			obj = self:AnalyzeTypeExpression(node.type_expression, obj)
		end

		node:AssociateType(obj or err)
		node.scope = self:GetScope()
		return obj, err
	end
end

function META:OnDiagnostic() end

function META:MapTypeToNode(typ, node)
	self.type_to_node[typ] = node
end

function META:GetTypeToNodeMap()
	return self.type_to_node
end

function META.New(config)
	config = config or {}

	if config.should_crawl_untyped_functions == nil then
		config.should_crawl_untyped_functions = true
	end

	local init = {
		config = config,
		compiler = false,
		processing_deferred_calls = false,
		SuppressDiagnostics = false,
		expect_diagnostic = false,
		diagnostics_map = false,
		type_checked = false,
		max_iterations = false,
		break_out_scope = false,
		_continue_ = false,
		tracked_tables = false,
		inverted_index_tracking = false,
		current_if_statement = false,
		deferred_calls = false,
		function_scope = false,
		call_stack = false,
		self_arg_stack = false,
		tracked_upvalues_done = false,
		tracked_upvalues = false,
		tracked_tables_done = false,
		scope = false,
		current_statement = false,
		left_assigned = false,
		current_expression = false,
		lua_error_thrown = false,
		max_loop_iterations = false,
		enable_random_functions = false,
		yielded_results = false,
		inverted_index_tracking = false,
		vars_table = false,
		type_table = false,
		analyzer = false,
		super_hack = false,
		stem_types = false,
		TealCompat = false,
		lua_assert_error_thrown = false,
		type_to_node = {},
		track_stash = {},
		analyzed_root_statements = {},
	}

	for _, func in ipairs(META.OnInitialize) do
		func(init)
	end

	local self = setmetatable(init, META)
	self.context_values = {}
	self.context_ref = {}
	return self
end

return META
