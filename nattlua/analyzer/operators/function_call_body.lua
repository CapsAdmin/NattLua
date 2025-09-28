local ipairs = ipairs
local table = _G.table
local error_messages = require("nattlua.error_messages")
local Tuple = require("nattlua.types.tuple").Tuple
local Table = require("nattlua.types.table").Table
local Union = require("nattlua.types.union").Union
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

	if not arg and contract:CanBeNil() then
		ok = true
	elseif not arg then
		ok, reason = false, error_messages.subset("*missing argument #" .. i .. "* ", contract)
	elseif arg.Type == "table" and contract.Type == "table" then
		ok, reason = arg:FollowsContract(contract)
	elseif arg.Type == "function" and contract.Type == "function" then
		ok, reason = arg:IsCallbackSubsetOf(contract)
	else
		ok, reason = arg:IsSubsetOf(contract)
	end

	if not ok then return false, error_messages.argument(i, reason) end

	return true
end

return function(self, obj, input)
	local function_node = obj:GetFunctionBodyNode()
	local is_generic_function = function_node.identifiers_typesystem
	local is_type_function = function_node.Type == "statement_local_type_function" or
		function_node.Type == "statement_type_function" or
		function_node.Type == "expression_type_function"
	-- analyze the input signature to resolve generics and other types
	local input_signature = obj:GetInputSignature()
	local input_signature_length = input_signature:GetSafeLength(input)
	local signature_override = {}

	-- before we call the function we have to compute the new input signature
	if obj:IsExplicitInputSignature() then
		self:CreateAndPushFunctionScope(obj)
		self:PushAnalyzerEnvironment("typesystem")

		if is_type_function then
			if is_generic_function then
				-- if this is a generics we create upvalues based on the generic arguments
				-- and the generic input signature, ie:
				-- foo<|1, 2|>(...)
				-- function foo<|TA, TB|>(a: TA, b: TB) end
				-- or
				-- local TA = 1
				-- local TB = 2
				-- (a: TA, b: TB)
				-- this makes the input signature become (a: 1, b: 2) when TA and TB evaluated later on
				local call_expression = self:GetCallStack()[1].call_node

				for i, identifier in ipairs(function_node.identifiers_typesystem) do
					local generic_type = call_expression.expressions_typesystem and
						call_expression.expressions_typesystem[i] or
						identifier
					local T = self:AnalyzeExpression(generic_type)
					self:CreateLocalValue(identifier.value:GetValueString(), T)
				end
			else
				-- without generics we just check the input against the input signature
				local new_tup, errors = input:SubsetWithoutExpansionOrFallbackWithTuple(obj:GetInputSignature())

				if errors then
					for i, v in ipairs(errors) do
						local reason, a, b, i = table.unpack(v)
						self:Error(error_messages.argument(i, error_messages.because(error_messages.subset(a, b), reason)))
					end
				end

				input = new_tup
			end
		end

		if function_node.identifiers[1] then
			-- analyze the type expressions
			-- function foo(a: >>number<<, b: >>string<<)
			-- against the input
			-- foo(1, "hello")
			for i = 1, input_signature_length do
				local identifier
				local type_expression

				if i == 1 and function_node.self_call then
					identifier = "self"
					type_expression = function_node
				else
					local node = function_node.identifiers[i - (
							function_node.self_call and
							1 or
							0
						)] or
						function_node.identifiers[#function_node.identifiers]
					identifier = node.value:GetValueString()
					type_expression = node.type_expression
				end

				local arg = input:GetWithNumber(i)
				local contract = input_signature:GetWithoutExpansion(i)

				if not arg then
					-- if the argument is missing we expand input with nil
					arg = Nil()
					input:Set(i, arg)
				elseif
					contract and
					contract:IsReferenceType() and
					(
						contract.Type ~= "function" or
						arg.Type ~= "function" or
						arg:IsArgumentsInferred()
					)
				then
					-- this is for ref arguments or untyped functions
					self:CreateLocalValue(identifier, arg)

					if arg.Type == "any" and arg.Type ~= contract.Type then arg = contract end

					arg:SetReferenceType(true)
					local ok, err = check_argument_against_contract(self, arg, contract, i)

					if not ok then self:Error(error_messages.argument(i, err)) end

					signature_override[i] = arg
				elseif type_expression then
					local val, err

					if function_node.self_call and i == 1 then
						val, err = input_signature:GetWithNumber(i)
					else
						self:CreateLocalValue(identifier, Any())
						val, err = self:AnalyzeExpression(type_expression)
					end

					if not val then
						val = Any()
						self:Error(error_messages.argument(i, err))
					end

					self:CreateLocalValue(identifier, val)
					signature_override[i] = val
				end

				-- coerce untyped functions to contract callbacks
				if arg and arg.Type == "function" then
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

								func:SetInputArgumentsInferred(true)
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

		self:PopAnalyzerEnvironment()
		self:PopScope()

		-- finally check the input against the generated signature
		for i = 1, input_signature_length do
			local arg, contract

			if self:IsTypesystem() then
				arg = input:GetWithoutExpansion(i)
				contract = signature_override[i] or input_signature:GetWithoutExpansion(i)
			else
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
				if is_generic_function then
					--[[
						local function test<|T: any|>(val: T): T
							return val
						end

						test<|number|>(1)
					]]
					-- if it's a ref argument we pass the incoming value
					local t = contract:GetFirstValue():Copy(nil, true)
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
				local doit = true

				if contract.Type == "union" then
					local t = contract:GetType("table")

					if t and t.PotentialSelf then doit = false end
				end

				if doit then
					-- if it's not a ref argument we pass the incoming value
					local t = contract:GetFirstValue():Copy(nil, true)
					t:SetContract(contract)
					input:Set(i, t)
				end
			else
				if arg.Type == "any" and arg.Type ~= contract.Type then
					local t = contract:GetFirstValue():Copy(nil, true)
					t:SetContract(contract)
					input:Set(i, t)
				end
			end
		end
	end

	-- crawl the function with the new arguments
	-- return_result is either a union of tuples or a single tuple
	local scope = self:CreateAndPushFunctionScope(obj)
	self:StashTrackedChanges()
	function_node.scope = scope
	obj.scope = scope
	self:PushGlobalEnvironment(
		function_node,
		self:GetDefaultEnvironment(self:GetCurrentAnalyzerEnvironment()),
		self:GetCurrentAnalyzerEnvironment()
	)
	local output_signature

	do -- create upvalues for the function's generics if any, arguments and output
		if
			function_node.Type == "statement_function" or
			function_node.Type == "statement_analyzer_function" or
			function_node.Type == "statement_type_function"
		then
			if function_node.self_call then
				self:CreateLocalValue("self", input:GetWithNumber(1) or Nil())
			end
		end

		-- setup runtime generics type arguments if any
		if is_generic_function then
			-- if this is a generics we setup the generic upvalues for the signature
			-- local function foo<|TA, TB|>(a: TA, b: TB) end
			-- foo<|A, B|>(...)
			-- create upvalues like TA = A, TB = B so that we can use them in the function arguments and body
			local call_expression = self:GetCallStack()[1].call_node

			for i, identifier in ipairs(function_node.identifiers_typesystem) do
				local generic_expression = call_expression.expressions_typesystem and
					call_expression.expressions_typesystem[i] or
					nil

				if generic_expression then
					local T = self:AnalyzeExpression(generic_expression)
					self:CreateLocalValue(identifier.value:GetValueString(), T)
				end
			end
		end

		-- then setup the runtime arguments
		for i, identifier in ipairs(function_node.identifiers) do
			local argi = function_node.self_call and (i + 1) or i

			if identifier.value.sub_type == "..." then
				local val, err = input:Slice(argi)

				if not val then return val, err end

				self:CreateLocalValue(identifier.value:GetValueString(), val)
			else
				local val

				if self:IsTypesystem() then
					-- pure typesystem function, generics are not used here
					-- function foo<|T|> end
					val = input:GetWithoutExpansion(argi) or Nil()
				else
					val = input:GetWithNumber(argi) or Nil()
				end

				-- this will error down the line if something is wrong with the input signature
				self:CreateLocalValue(identifier.value:GetValueString(), val)
			end
		end

		-- if we have an explicit output type we must also set this up for this call
		-- note that this is done after generics and other types are setup, so that we can access then
		-- from the output type
		-- ie function foo<|T|>(): T end
		if function_node.return_types then
			self:PushAnalyzerEnvironment("typesystem")
			output_signature = Tuple(self:AnalyzeExpressions(function_node.return_types))
			self:PopAnalyzerEnvironment()
		end
	end

	if is_type_function then self:PushAnalyzerEnvironment("typesystem") end

	local returns = self:AnalyzeStatementsAndCollectOutputSignatures(function_node)

	if is_type_function then self:PopAnalyzerEnvironment() end

	self:PopGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
	self:PopScope()
	self:ClearScopedTrackedObjects(scope)
	self:PopStashedTrackedChanges()
	restore_mutated_types(self)
	-- used for analyzing side effects
	obj:AddScope(scope)

	-- if the function is untyped we warn about untyped arguments
	-- and we also merge merge the input into the function's input signature
	-- this way we get a more accurate picture of what the function does
	if not obj:IsExplicitInputSignature() then
		if not obj:IsArgumentsInferred() and function_node.identifiers then
			for i in ipairs(obj:GetInputSignature():GetData()) do
				if function_node.self_call then
					-- we don't count the actual self argument
					local node = function_node.identifiers[i + 1]

					if node and not node.type_expression then
						self:Warning(error_messages.untyped_argument(), node.type_expression)
					end
				elseif
					function_node.identifiers[i] and
					not function_node.identifiers[i].type_expression
				then
					if not obj:IsInputArgumentsInferred() then
						self:Warning(error_messages.untyped_argument(), function_node.identifiers[i])
					end
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

	local output

	do
		local union = {}

		for i, ret in ipairs(returns) do
			if #ret.types == 1 then
				union[i] = ret.types[1]
			elseif #ret.types == 0 then
				union[i] = Nil()
			else
				union[i] = Tuple(ret.types)
			end
		end

		if #union == 1 then
			if union[1].Type == "tuple" then
				output = union[1]
			elseif union[1].Type == "union" then
				output = union[1]
				output = output:Simplify()

				if output.Type ~= "tuple" then output = Tuple({output}) end
			else
				output = Tuple({union[1]})
			end
		else
			output = Union(union):Simplify()

			if output.Type ~= "tuple" then output = Tuple({output}) end
		end
	end

	if not obj:IsExplicitOutputSignature() then
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

	output_signature = output_signature or obj:GetOutputSignature()

	-- check against the function's return type
	for _, ret in ipairs(returns) do
		local output = nil

		if #ret.types == 0 then
			output = Tuple({Nil()})
		else
			output = Tuple(ret.types)
		end

		local output_signature = output_signature
		local function_node = ret.node

		if self:IsTypesystem() then
			-- in the typesystem we must not unpack tuples when checking
			local new_tup, err = output:SubsetWithoutExpansionOrFallbackWithTuple(output_signature)

			if err then
				for i, v in ipairs(err) do
					local reason, a, b, i = table.unpack(v)
					self:Error(error_messages.return_(i, error_messages.because(error_messages.subset(a, b), reason)))
				end
			end

			output = new_tup
		end

		if
			output_signature:HasOneValue() and
			output_signature:GetWithNumber(1).Type == "union" and
			output_signature:GetWithNumber(1):HasType("tuple")
		then
			output_signature = output_signature:GetWithNumber(1)
		end

		if output.Type == "tuple" and output:HasOneValue() then
			local first_val = output:GetWithNumber(1)

			if first_val then
				if first_val.Type == "union" and first_val:HasType("tuple") then
					output = output:GetWithNumber(1)
				elseif first_val.Type == "tuple" then
					output = first_val
				end
			end
		end

		if output.Type ~= "union" then
			if output_signature.Type == "union" then
				local errors = {}
				local check = false

				for _, contract in ipairs(output_signature:GetData()) do
					local ok, reason = output:IsSubsetOfTuple(contract)

					if ok then
						-- something is ok then just break out of this work item and continue
						check = false

						break
					else
						check = true
						table.insert(errors, reason)
					end
				end

				if check then
					for _, error in ipairs(errors) do
						self:Error(error)
					end
				end
			else
				local check = true

				if output.Type == "tuple" and output:HasOneValue() then
					local val = self:GetFirstValue(output) or Nil()

					if val.Type == "union" and val:GetCardinality() == 0 then
						check = false
					end
				end

				if check then
					local err = output:IsNotSubsetOfTuple(output_signature)

					if err then
						for i, v in ipairs(err) do
							local reason, a, b, i = v[1], v[2], v[3], v[4]
							self:PushCurrentStatement(function_node)
							self:PushCurrentExpression(function_node.return_types and function_node.return_types[i])
							self:Error(error_messages.return_(i, error_messages.because(error_messages.subset(a, b), reason)))
							self:PopCurrentExpression()
							self:PopCurrentStatement()
						end
					end
				end
			end
		end
	end

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
