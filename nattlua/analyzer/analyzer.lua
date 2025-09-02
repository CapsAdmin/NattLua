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
		self:CheckTimeout()
		self:PushCurrentStatement(node)
		self:PushAnalyzerEnvironment(node.environment or "runtime")

		if node.kind == "assignment" or node.kind == "local_assignment" then
			AnalyzeAssignment(self, node)
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
		elseif node.kind == "call_expression" then
			self:AnalyzeExpression(node.value)
		elseif node.kind == "continue" then
			self._continue_ = true
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
				local key = ConstString(key.value.value)
				local val = AnalyzeFunction(self, node)
				self:SetLocalOrGlobalValue(key, val)
			end

			self:PopAnalyzerEnvironment()
		elseif node.kind == "generic_for" then
			AnalyzeGenericFor(self, node)
		elseif node.kind == "numeric_for" then
			AnalyzeNumericFor(self, node)
		elseif node.kind == "analyzer_debug_code" then
			local code = node.lua_code.value.value:sub(3)
			self:CallLuaTypeFunction(node.compiled_function, self:GetScope(), {})
		elseif node.kind == "import" then

		elseif
			node.kind ~= "end_of_file" and
			node.kind ~= "semicolon" and
			node.kind ~= "shebang" and
			node.kind ~= "goto_label" and
			node.kind ~= "parser_debug_code" and
			node.kind ~= "goto" and
			node.kind ~= "error"
		then
			self:FatalError("unhandled statement: " .. tostring(node))
		end

		node.scope = self:GetScope()
		self:PopAnalyzerEnvironment()
		self:PopCurrentStatement()
	end
end

do
	local BinaryCustom = require("nattlua.analyzer.operators.binary").BinaryCustom
	local Binary = require("nattlua.analyzer.operators.binary").Binary
	local AnalyzePostfixCall = require("nattlua.analyzer.expressions.postfix_call").AnalyzePostfixCall
	local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
	local AnalyzeTable = require("nattlua.analyzer.expressions.table").AnalyzeTable
	local AnalyzeAtomicValue = require("nattlua.analyzer.expressions.atomic_value").AnalyzeAtomicValue
	local LookupValue = require("nattlua.analyzer.expressions.atomic_value").LookupValue
	local AnalyzeLSX = require("nattlua.analyzer.expressions.lsx").AnalyzeLSX
	local Union = require("nattlua.types.union").Union
	local Tuple = require("nattlua.types.tuple").Tuple
	local VarArg = require("nattlua.types.tuple").VarArg
	local Prefix = require("nattlua.analyzer.operators.prefix").Prefix
	local Node = require("nattlua.parser.node")
	local Any = require("nattlua.types.any").Any

	function META:AnalyzeRuntimeExpression(node)
		if node.kind == "value" then
			return AnalyzeAtomicValue(self, node)
		elseif node.kind == "binary_operator" then
			return self:AssertWithNode(node, Binary(self, node))
		elseif node.kind == "prefix_operator" then
			return self:Assert(Prefix(self, node))
		elseif node.kind == "postfix_call" then
			return AnalyzePostfixCall(self, node)
		elseif node.kind == "postfix_expression_index" then
			return self:Assert(
				self:IndexOperator(
					self:Assert(self:AnalyzeExpression(node.left)),
					self:Assert(self:AnalyzeExpression(node.expression))
				)
			)
		elseif node.kind == "table" or node.kind == "type_table" then
			return AnalyzeTable(self, node)
		elseif
			node.kind == "function" or
			node.kind == "analyzer_function" or
			node.kind == "type_function" or
			node.kind == "function_signature"
		then
			return AnalyzeFunction(self, node)
		elseif node.kind == "vararg" then
			if node.value then return VarArg(self:AnalyzeExpression(node.value)) end

			return LookupValue(self, "...")
		elseif node.kind == "postfix_operator" then
			if node.value.value == "++" then
				local r = self:AnalyzeExpression(node.left)
				return BinaryCustom(self, setmetatable({value = {value = "+"}}, Node), r, r, "+")
			end
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
		elseif node.kind == "error" then
			-- do nothing with error nodes, they are just placeholders for the parser to be able to continue
			return Any()
		end

		self:FatalError("unhandled expression " .. node.kind)
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
		if node.error_node then return Any() end

		self:PushCurrentExpression(node)
		local obj, err = self:AnalyzeRuntimeExpression(node)

		if not obj then self:Error(err) end

		self:PopCurrentExpression()

		if obj and node.type_expression then
			self:PushCurrentExpression(node.type_expression)
			obj, err = self:AnalyzeTypeExpression(node.type_expression, obj)

			if not obj then self:Error(err) end

			self:PopCurrentExpression()
		end

		if obj then node:AssociateType(obj) end

		node.scope = self:GetScope()
		return obj, err
	end

	function META:TestFunctionAssertDiagnosticCount(count)
		count = count or 0
		self:AnalyzeUnreachableCode()

		if #self:GetDiagnostics() ~= count then
			error("expected no diagnostics reported", 2)
		end
	end

	function META:AnalyzeConditionalExpression(exp)
		self:PushCurrentExpression(exp)
		local no_operator_expression = exp.kind ~= "binary_operator" and
			exp.kind ~= "prefix_operator" or
			(
				exp.kind == "binary_operator" and
				exp.value.value == "."
			)

		if no_operator_expression then self:PushTruthyExpressionContext() end

		local obj = self:Assert(self:AnalyzeExpression(exp))
		self:TrackDependentUpvalues(obj)

		if no_operator_expression then self:PopTruthyExpressionContext() end

		-- Union tracking
		if no_operator_expression and obj.Type == "union" then
			self:TrackUpvalueUnion(obj, obj:GetTruthy(), obj:GetFalsy())
		end

		self:PopCurrentExpression()
		self:TrackDependentUpvalues(obj)
		return obj
	end

	local max_iterations = 20000

	function META:CheckTimeout()
		self.check_count = (self.check_count or 0) + 1
		local count = self.check_count

		if count < max_iterations - (max_iterations * 0.1) then return end

		self.timeout = self.timeout or {}
		local node = self:GetCurrentStatement()

		if not node then return end

		self.timeout[node] = (self.timeout[node] or 0) + 1

		if count < max_iterations then return end

		local top = {}

		for node, count in pairs(self.timeout) do
			if count > 5 then table.insert(top, {node = node, count = count}) end
		end

		table.sort(top, function(a, b)
			return a.count > b.count
		end)

		for i, info in ipairs(top) do
			if i > 10 then break end

			self:Warning({info.node, " was crawled ", info.count, " times"})
			print(info.node, " was crawled ", info.count, " times")
		end

		self:FatalError("too many iterations (" .. count .. "), stopping execution")
	end
end

function META:OnDiagnostic() end

function META:MapTypeToNode(typ, node)
	self.type_to_node[typ] = node
end

function META:GetTypeToNodeMap()
	return self.type_to_node
end

function META:__tostring()
	return ("analyzer[%p][%s]"):format(self, self.config.file_path or self.config.file_name)
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
		loaded_modules = {},
		parsed_paths = {},
		check_count = 0,
		call_stack_map = {},
		LEFT_SIDE_OR = false,
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
