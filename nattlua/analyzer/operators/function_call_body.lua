local ipairs = ipairs
local table = _G.table
local type_errors = require("nattlua.types.error_messages")
local Tuple = require("nattlua.types.tuple").Tuple
local Table = require("nattlua.types.table").Table
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any
local Function = require("nattlua.types.function").Function
local table_clear = require("nattlua.other.tablex").clear

local function mutate_type(self, i, arg, contract, arguments)
	local env = self:GetScope():GetNearestFunctionScope()
	arg:PushContract(contract)
	arg.argument_index = i
	arg:ClearMutations()
	table.insert(env.mutated_types, {arg = arg, mutations = arg:GetMutations()})
	arguments:Set(i, arg)
end

local function restore_mutated_types(self)
	local env = self:GetScope():GetNearestFunctionScope()

	if not env.mutated_types[1] then return end

	for _, data in ipairs(env.mutated_types) do
		data.arg:PopContract()
		data.arg.argument_index = false
		data.arg:SetMutations(data.mutations)
		self:MutateUpvalue(data.arg:GetUpvalue(), data.arg)
	end

	table_clear(env.mutated_types)
end

local function shrink_union_to_function_signature(obj)
	local arg = Tuple()
	local ret = Tuple()

	for _, func in ipairs(obj:GetData()) do
		if func.Type ~= "function" then return false end

		arg:Merge(func:GetInputSignature())
		ret:Merge(func:GetOutputSignature())
	end

	return Function(arg, ret)
end

local function check_argument_against_contract(self, arg, contract, i)
	local ok, reason

	if not arg then
		if contract:IsFalsy() then
			arg = Nil()
			ok = true
		else
			ok = false
			reason = type_errors.subset("*missing argument #" .. i .. "* ", contract)
		end
	elseif arg.Type == "table" and contract.Type == "table" then
		ok, reason = arg:FollowsContract(contract)
	else
		if arg.Type == "function" and contract.Type == "function" then
			ok, reason = arg:IsCallbackSubsetOf(contract)
		else
			ok, reason = arg:IsSubsetOf(contract)
		end
	end

	if not ok then
		return false, type_errors.context("argument #" .. i .. ":", reason)
	end

	return true
end

local function check_input(self, obj, input)
	if not obj:IsExplicitInputSignature() then
		-- if this function is completely untyped we don't check any input
		return input
	end

	local function_node = obj:GetFunctionBodyNode()
	self:CreateAndPushFunctionScope(obj)
	self:PushAnalyzerEnvironment("typesystem")

	if
		function_node.kind == "local_type_function" or
		function_node.kind == "type_function"
	then
		if not function_node.identifiers_typesystem and obj:IsExplicitInputSignature() then
			if self:IsTypesystem() then
				local new_tup, err = input:SubsetWithoutExpansionOrFallbackWithTuple(obj:GetInputSignature())

				if err then
					for i, v in ipairs(err) do
						local reason, a, b, i = table.unpack(v)
						self:Error(
							type_errors.context("argument #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
						)
					end
				end

				input = new_tup
			else
				local new_tup, err = input:SubsetOrFallbackWithTuple(obj:GetInputSignature())

				if err then
					for i, v in ipairs(err) do
						local reason, a, b, i = table.unpack(v)
						self:Error(
							type_errors.context("argument #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
						)
					end
				end

				input = new_tup
			end
		end

		if function_node.identifiers_typesystem then
			-- if this is a generics we setup the generic upvalues for the signature
			local call_expression = self:GetCallStack()[1].call_node

			for i, generic_upvalue in ipairs(function_node.identifiers_typesystem) do
				local generic_type = call_expression.expressions_typesystem and
					call_expression.expressions_typesystem[i] or
					generic_upvalue
				local T = self:AnalyzeExpression(generic_type)
				self:CreateLocalValue(generic_upvalue.value.value, T)
			end
		end
	end

	-- analyze the input signature to resolve generics and other types
	local function_node = obj:GetFunctionBodyNode()
	local input_signature = obj:GetInputSignature()
	local input_signature_length = input_signature:GetSafeLength(input)
	local signature_override = {}

	if function_node.identifiers[1] then
		-- analyze the type expressions
		-- function foo(a: >>number<<, b: >>string<<)
		-- against the input
		-- foo(1, "hello")
		for i = 1, input_signature_length do
			local node
			local identifier
			local type_expression

			if i == 1 and function_node.self_call then
				node = function_node
				identifier = "self"
				type_expression = function_node
			else
				local i = i

				if function_node.self_call then i = i - 1 end

				node = function_node.identifiers[i] or
					function_node.identifiers[#function_node.identifiers]
				identifier = node.value.value
				type_expression = node.type_expression
			end

			-- stem type so that we can allow
			-- function(x: foo<|x|>): nil
			self:CreateLocalValue(identifier, Any())
			local contract

			if identifier == "..." or self:IsTypesystem() then
				contract = input_signature:GetWithoutExpansion(i)
			else
				contract = input_signature:GetWithNumber(i)
			end

			local arg = input:GetWithNumber(i)

			if not arg then
				arg = Nil()
				input:Set(i, arg)
			end

			if
				contract and
				contract:IsReferenceType() and
				(
					contract.Type ~= "function" or
					arg.Type ~= "function" or
					arg:IsArgumentsInferred()
				)
			then
				self:CreateLocalValue(identifier, arg)
				signature_override[i] = arg
				signature_override[i]:SetReferenceType(true)
				local ok, err = check_argument_against_contract(self, signature_override[i], contract, i)

				if not ok then
					self:Error(type_errors.context("argument #" .. i, err))
				end
			elseif type_expression then
				local val, err

				if function_node.self_call and i == 1 then
					val, err = input_signature:GetWithNumber(1)

					if not val then
						self:Error(type_errors.context("argument #" .. i, err))
					end
				else
					val, err = self:AnalyzeExpression(type_expression)

					if not function_node.identifiers_typesystem then

					--val, err = self:GetFirstValue(val)
					end

					if not val then
						self:Error(type_errors.context("argument #" .. i, err))
					end
				end

				signature_override[i] = val
				self:CreateLocalValue(identifier, signature_override[i])
			end
		end
	end

	self:PopAnalyzerEnvironment()
	self:PopScope()

	do -- coerce untyped functions to contract callbacks
		for i = 1, input_signature_length do
			local arg = input:GetWithNumber(i)

			if arg.Type == "function" then
				local func = arg

				if
					signature_override[i] and
					signature_override[i].Type == "union" and
					not signature_override[i]:IsReferenceType()
				then
					local merged = shrink_union_to_function_signature(signature_override[i])

					if merged then
						func:SetInputSignature(merged:GetInputSignature())
						func:SetOutputSignature(merged:GetOutputSignature())
						func:SetExplicitInputSignature(true)
						func:SetExplicitOutputSignature(true)
						func:SetCalled(false)
					end
				else
					if not func:IsExplicitInputSignature() then
						local contract = signature_override[i] or obj:GetInputSignature():GetWithNumber(i)

						if contract then
							if contract.Type == "union" then
								local tup = Tuple()

								for _, func in ipairs(contract:GetData()) do
									tup:Merge(func:GetInputSignature())
								end

								func:SetInputSignature(tup)
							elseif contract.Type == "function" then
								local len = func:GetInputSignature():GetTupleLength()
								local new = contract:GetInputSignature():Copy(nil, true)
								local err

								if not contract:GetInputSignature():IsInfinite() then
									new, err = new:Slice(1, len)
								end

								if not new then
									self:Error(err)
								else
									func:SetInputSignature(new) -- force copy tables so we don't mutate the contract
								end
							end

							func:SetCalled(false)
						end
					end

					if not func:IsExplicitOutputSignature() then
						local contract = signature_override[i] or obj:GetOutputSignature():GetWithNumber(i)

						if contract then
							if contract.Type == "union" then
								local tup = Tuple()

								for _, func in ipairs(contract:GetData()) do
									tup:Merge(func:GetOutputSignature())
								end

								func:SetOutputSignature(tup)
							elseif contract.Type == "function" then
								func:SetOutputSignature(contract:GetOutputSignature())
							end

							func:SetExplicitOutputSignature(true)
							func:SetCalled(false)
						end
					end
				end
			end
		end
	end

	-- finally check the input against the generated signature
	for i = 1, input_signature_length do
		local arg, contract

		if self:IsTypesystem() then
			arg = input:GetWithoutExpansion(i)
			contract = signature_override[i] or input_signature:GetWithoutExpansion(i)
		end

		if self:IsRuntime() then
			arg = input:GetWithNumber(i)
			contract = signature_override[i] or input_signature:GetWithNumber(i)
		end

		if contract.Type == "union" then
			local shrunk = shrink_union_to_function_signature(contract)

			if shrunk then contract = shrunk end
		end

		local ok, reason = check_argument_against_contract(self, arg, contract, i)

		if not ok then self:Error(reason) end

		if self:IsTypesystem() then
			local doit = self:IsRuntime()

			if function_node.identifiers_typesystem then doit = true end

			if contract.Type == "union" then
				local t = contract:GetType("table")

				if t and t.PotentialSelf then doit = false end
			end

			if doit then
				-- if it's a ref argument we pass the incoming value
				local t = contract:GetFirstValue():Copy()
				t:SetContract(contract)
				input:Set(i, t)
			end
		elseif
			arg and
			arg.Type == "table" and
			contract.Type == "table" and
			arg:GetUpvalue() and
			not contract:IsReferenceType()
		then
			mutate_type(self, i, arg, contract, input)
		elseif not contract:IsReferenceType() then
			local doit = self:IsRuntime()

			if function_node.identifiers_typesystem then doit = true end

			if contract.Type == "union" then
				local t = contract:GetType("table")

				if t and t.PotentialSelf then doit = false end
			end

			if doit then
				-- if it's a ref argument we pass the incoming value
				local t = contract:GetFirstValue():Copy()
				t:SetContract(contract)
				input:Set(i, t)
			end
		end
	end

	return input
end

local function check_output(self, output, output_signature, function_node)
	if self:IsTypesystem() then
		-- in the typesystem we must not unpack tuples when checking
		local new_tup, err = output:SubsetWithoutExpansionOrFallbackWithTuple(output_signature)

		if err then
			for i, v in ipairs(err) do
				local reason, a, b, i = table.unpack(v)
				self:Error(
					type_errors.context("return #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
				)
			end
		end

		output = new_tup
	end

	local original_contract = output_signature

	if
		output_signature:HasOneValue() and
		output_signature:GetWithNumber(1).Type == "union" and
		output_signature:GetWithNumber(1):HasType("tuple")
	then
		output_signature = output_signature:GetWithNumber(1)
	end

	if output.Type == "tuple" and output:HasOneValue() then
		local first_val = output:GetWithNumber(1)

		if first_val and first_val.Type == "union" and first_val:HasType("tuple") then
			output = output:GetWithNumber(1)
		end
	end

	if output.Type == "union" then
		-- typically a function with mutliple uncertain returns
		for _, obj in ipairs(output:GetData()) do
			if obj.Type ~= "tuple" then
				-- if the function returns one value it's not in a tuple
				obj = Tuple({obj})
			end

			-- check each tuple in the union
			check_output(self, obj, original_contract, function_node)
		end
	else
		if output_signature.Type == "union" then
			local errors = {}

			for _, contract in ipairs(output_signature:GetData()) do
				local ok, reason = output:IsSubsetOfTuple(contract)

				if ok then
					-- something is ok then just return and don't report any errors found
					return
				else
					table.insert(errors, {contract = contract, reason = reason})
				end
			end

			for _, error in ipairs(errors) do
				self:Error(error.reason)
			end
		else
			if output.Type == "tuple" and output:HasOneValue() then
				local val = self:GetFirstValue(output) or Nil()

				if val.Type == "union" and val:GetCardinality() == 0 then return end
			end

			local _, err = output:SubsetOrFallbackWithTuple(output_signature)

			if err then
				for i, v in ipairs(err) do
					local reason, a, b, i = table.unpack(v)
					self:PushCurrentStatement(function_node)
					self:PushCurrentExpression(function_node.return_types and function_node.return_types[i])
					self:Error(
						type_errors.context("return #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
					)
					self:PopCurrentExpression()
					self:PopCurrentStatement()
				end
			end
		end
	end
end

return function(self, obj, input)
	local function_node = obj:GetFunctionBodyNode()
	local is_type_function = function_node.kind == "local_type_function" or
		function_node.kind == "type_function"
	input = check_input(self, obj, input)
	-- crawl the function with the new arguments
	-- return_result is either a union of tuples or a single tuple
	local scope = self:CreateAndPushFunctionScope(obj)
	self:StashTrackedChanges()
	function_node.scope = scope
	obj.scope = scope
	self:PushTruthyExpressionContext(false)
	self:PushFalsyExpressionContext(false)
	self:PushGlobalEnvironment(
		function_node,
		self:GetDefaultEnvironment(self:GetCurrentAnalyzerEnvironment()),
		self:GetCurrentAnalyzerEnvironment()
	)

	if function_node.self_call then
		self:CreateLocalValue("self", input:GetWithNumber(1) or Nil())
	end

	-- first setup runtime generics type arguments if any
	if function_node.identifiers_typesystem then
		-- if this is a generics we setup the generic upvalues for the signature
		local call_expression = self:GetCallStack()[1].call_node

		for i, generic_upvalue in ipairs(function_node.identifiers_typesystem) do
			local generic_type = call_expression.expressions_typesystem and
				call_expression.expressions_typesystem[i] or
				nil

			if generic_type then
				local T = self:AnalyzeExpression(generic_type)
				self:CreateLocalValue(generic_upvalue.value.value, T)
			end
		end
	end

	-- then setup the runtime arguments
	for i, identifier in ipairs(function_node.identifiers) do
		local argi = function_node.self_call and (i + 1) or i

		if self:IsTypesystem() then
			if identifier.value.value == "..." then
				local val, err = input:Slice(argi)

				if not val then return val, err end

				self:CreateLocalValue(identifier.value.value, val)
			else
				local val, err = input:GetWithoutExpansion(argi)

				if not val then
					local t = obj:GetInputSignature():GetWithoutExpansion(argi)

					if t and t:IsNil() then
						err = nil
						val = Nil()
					end
				end

				if not val then
					self:Error(err)
					val = Nil()
				end

				self:CreateLocalValue(identifier.value.value, val)
			end
		end

		if self:IsRuntime() then
			if identifier.value.value == "..." then
				local val, err = input:Slice(argi)

				if not val then return val, err end

				self:CreateLocalValue(identifier.value.value, val)
			else
				local val, err = input:GetWithNumber(argi)

				if not val then
					val = Nil()
					local arg = obj:GetInputSignature():GetWithNumber(argi)

					if arg and arg:IsReferenceType() then val:SetReferenceType(true) end
				end

				if not val then
					self:Error(err)
					val = Any()
				end

				self:CreateLocalValue(identifier.value.value, val)
			end
		end
	end

	do
		local len = #function_node.identifiers

		if
			function_node.identifiers[#function_node.identifiers] and
			function_node.identifiers[#function_node.identifiers].value.value == "..."
		then

		else
			if function_node.self_call then len = len + 1 end

			if #input:GetData() > len then
				self:Error(type_errors.missing_index(len + 1))
			end
		end
	end

	-- if we have a return type we must also set this up for this call
	local output_signature = obj:IsExplicitOutputSignature() and obj:GetOutputSignature()

	if function_node.return_types then
		self:PushAnalyzerEnvironment("typesystem")
		output_signature = Tuple(self:AnalyzeExpressions(function_node.return_types))
		self:PopAnalyzerEnvironment()
	end

	if is_type_function then self:PushAnalyzerEnvironment("typesystem") end

	local output = self:AnalyzeStatementsAndCollectOutputSignatures(function_node)

	if is_type_function then self:PopAnalyzerEnvironment() end

	self:PopGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
	self:PopScope()
	self:PopFalsyExpressionContext()
	self:PopTruthyExpressionContext()
	self:ClearScopedTrackedObjects(scope)
	self:PopStashedTrackedChanges()

	if output.Type ~= "tuple" then output = Tuple({output}) end

	restore_mutated_types(self)
	-- used for analyzing side effects
	obj:AddScope(input, output, scope)

	if not obj:IsExplicitInputSignature() then
		if not obj:IsArgumentsInferred() and function_node.identifiers then
			for i in ipairs(obj:GetInputSignature():GetData()) do
				if function_node.self_call then
					-- we don't count the actual self argument
					local node = function_node.identifiers[i + 1]

					if node and not node.type_expression then
						self:Warning(type_errors.untyped_argument(), node.type_expression)
					end
				elseif
					function_node.identifiers[i] and
					not function_node.identifiers[i].type_expression
				then
					self:Warning(type_errors.untyped_argument(), function_node.identifiers[i])
				end
			end
		end

		local tup, err = input:Slice(1, obj:GetInputSignature():GetMinimumLength())

		if not tup then
			self:Error(err)
		else
			obj:GetInputSignature():Merge(tup)
		end
	end

	do -- this is for the emitter
		if function_node.identifiers then
			for i, node in ipairs(function_node.identifiers) do
				local obj = obj:GetInputSignature():GetWithNumber(i)

				if obj then node:AssociateType(obj) end
			end
		end

		function_node:AssociateType(obj)
	end

	if not output_signature then
		-- if there is no return type 
		if function_node.environment == "runtime" then
			local copy

			for i, v in ipairs(output:GetData()) do
				if v.Type == "table" and not v:GetContract() then
					copy = copy or output:Copy()
					local tbl = Table()

					for _, kv in ipairs(v:GetData()) do
						tbl:Set(kv.key, self:GetMutatedTableValue(v, kv.key))
					end

					copy:Set(i, tbl)
				end
			end

			obj:GetOutputSignature():Merge(copy or output)
		end

		return output
	end

	-- check against the function's return type
	check_output(self, output, output_signature, function_node)

	if function_node.environment == "typesystem" then return output end

	local contract = output_signature:Copy()

	for _, v in ipairs(contract:GetData()) do
		if v.Type == "table" then v:SetReferenceId(false) end
	end

	-- if a return type is marked with ref, it will pass the ref value back to the caller
	-- a bit like generics
	for i, v in ipairs(output_signature:GetData()) do
		if v:IsReferenceType() then contract:Set(i, output:GetWithNumber(i)) end
	end

	return contract
end
