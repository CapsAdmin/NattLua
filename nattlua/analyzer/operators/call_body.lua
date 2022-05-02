local ipairs = ipairs
local table = _G.table
local type_errors = require("nattlua.types.error_messages")
local Tuple = require("nattlua.types.tuple").Tuple
local Table = require("nattlua.types.table").Table
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any
local Function = require("nattlua.types.function").Function

local function mutate_type(self, i, arg, contract, arguments)
	local env = self:GetScope():GetNearestFunctionScope()
	env.mutated_types = env.mutated_types or {}
	arg:PushContract(contract)
	arg.argument_index = i
	table.insert(env.mutated_types, arg)
	arguments:Set(i, arg)
end

local function restore_mutated_types(self)
	local env = self:GetScope():GetNearestFunctionScope()

	if not env.mutated_types or not env.mutated_types[1] then return end

	for _, arg in ipairs(env.mutated_types) do
		arg:PopContract()
		arg.argument_index = nil
		self:MutateUpvalue(arg:GetUpvalue(), arg)
	end

	env.mutated_types = {}
end

local function shrink_union_to_function_signature(obj)
	local arg = Tuple({})
	local ret = Tuple({})

	for _, func in ipairs(obj:GetData()) do
		if func.Type ~= "function" then return false end

		arg:Merge(func:GetInputSignature())
		ret:Merge(func:GetOutputSignature())
	end

	return Function(arg, ret)
end

local function check_argument_against_contract(arg, contract, i)
	local ok, reason

	if not arg then
		if contract:IsFalsy() then
			arg = Nil()
			ok = true
		else
			ok, reason = type_errors.other(
				{
					"argument #",
					i,
					" expected ",
					contract,
					" got nil",
				}
			)
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
		return type_errors.other({"argument #", i, " ", arg, ": ", reason})
	end

	return true
end

local function check_input(self, obj, input)
	if not obj:IsExplicitInputSignature() then
		-- if this function is completely untyped we don't check any input
		return true
	end

	local function_node = obj:GetFunctionBodyNode()

	if
		function_node.kind == "local_type_function" or
		function_node.kind == "type_function"
	then
		if not function_node.identifiers_typesystem and obj:IsExplicitInputSignature() then
			-- if this is a type function we just do a simple check and arguments are passed as is
			local ok, reason, a, b, i = input:IsSubsetOfTupleWithoutExpansion(obj:GetInputSignature())

			if not ok then
				return type_errors.subset(a, b, {"argument #", i, " - ", reason})
			end

			return ok, reason
		end

		if function_node.identifiers_typesystem then
			-- if this is a generics we setup the generic upvalues for the signature
			local call_expression = self:GetCallStack()[1].call_node

			for i = 1, #function_node.identifiers do
				if function_node.self_call then i = i + 1 end

				local generic_upvalue = function_node.identifiers_typesystem and
					function_node.identifiers_typesystem[i] or
					nil
				local generic_type = call_expression.expressions_typesystem and
					call_expression.expressions_typesystem[i] or
					nil

				if generic_type and generic_upvalue then
					local T = self:AnalyzeExpression(generic_type)
					self:CreateLocalValue(generic_upvalue.value.value, T)
				end
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
		self:CreateAndPushFunctionScope(obj)
		self:PushAnalyzerEnvironment("typesystem")

		for i = 1, input_signature_length do
			local node = function_node.identifiers[i] --[[argument]] or
				function_node.identifiers[#function_node.identifiers]
			--[[or the vararg]] local identifier = node.value.value
			local type_expression = node.type_expression

			if function_node.self_call then i = i + 1 end

			-- stem type so that we can allow
			-- function(x: foo<|x|>): nil
			self:CreateLocalValue(identifier, Any())
			local contract

			if identifier == "..." then
				contract = input_signature:GetWithoutExpansion(i)
			else
				contract = input_signature:Get(i)
			end

			local arg = input:Get(i)

			if not arg then
				arg = Nil()
				input:Set(i, arg)
			end

			if
				contract and
				contract.ref_argument and
				(
					contract.Type ~= "function" or
					arg.Type ~= "function" or
					arg:IsArgumentsInferred()
				)
			then
				self:CreateLocalValue(identifier, arg)
				signature_override[i] = arg
				signature_override[i].ref_argument = true
				local ok, err = signature_override[i]:IsSubsetOf(contract)

				if not ok then
					return type_errors.other({"argument #", i, " ", arg, ": ", err})
				end
			elseif type_expression then
				signature_override[i] = self:AnalyzeExpression(type_expression):GetFirstValue()
				self:CreateLocalValue(identifier, signature_override[i])
			end

			if
				contract and
				contract.literal_argument and
				not self.processing_deferred_calls and
				arg and
				not arg:IsLiteral()
			then
				return type_errors.other({"argument #", i, " ", arg, ": not literal"})
			end
		end

		self:PopAnalyzerEnvironment()
		self:PopScope()
	end

	do -- coerce untyped functions to contract callbacks
		for i = 1, input_signature_length do
			local arg = input:Get(i)

			if arg.Type == "function" then
				local func = arg

				if
					signature_override[i] and
					signature_override[i].Type == "union" and
					not signature_override[i].ref_argument
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
						local contract = signature_override[i] or obj:GetInputSignature():Get(i)

						if contract then
							if contract.Type == "union" then
								local tup = Tuple({})

								for _, func in ipairs(contract:GetData()) do
									tup:Merge(func:GetInputSignature())
								end

								func:SetInputSignature(tup)
							elseif contract.Type == "function" then
								func:SetInputSignature(contract:GetInputSignature():Copy(nil, true)) -- force copy tables so we don't mutate the contract
							end

							func:SetCalled(false)
						end
					end

					if not func:IsExplicitOutputSignature() then
						local contract = signature_override[i] or obj:GetOutputSignature():Get(i)

						if contract then
							if contract.Type == "union" then
								local tup = Tuple({})

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
		local arg = input:Get(i)
		local contract = signature_override[i] or input_signature:Get(i)

		if contract.Type == "union" then
			local shrunk = shrink_union_to_function_signature(contract)

			if shrunk then contract = shrunk end
		end

		local ok, reason = check_argument_against_contract(arg, contract, i)

		if not ok then
			restore_mutated_types(self)
			return ok, reason
		end

		if
			arg.Type == "table" and
			contract.Type == "table" and
			arg:GetUpvalue() and
			not contract.ref_argument
		then
			mutate_type(self, i, arg, contract, input)
		elseif not contract.ref_argument then
			-- if it's a ref argument we pass the incoming value
			local t = contract:Copy()
			t:SetContract(contract)
			input:Set(i, t)
		end
	end

	return true
end

local function check_output(self, output, output_signature)
	if self:IsTypesystem() then
		-- in the typesystem we must not unpack tuples when checking
		local ok, reason, a, b, i = output:IsSubsetOfTupleWithoutExpansion(output_signature)

		if not ok then
			local _, err = type_errors.subset(a, b, {"return #", i, " '", b, "': ", reason})
			self:Error(err)
		end

		return
	end

	local original_contract = output_signature

	if
		output_signature:GetLength() == 1 and
		output_signature:Get(1).Type == "union" and
		output_signature:Get(1):HasType("tuple")
	then
		output_signature = output_signature:Get(1)
	end

	if
		output.Type == "tuple" and
		output:GetLength() == 1 and
		output:Get(1) and
		output:Get(1).Type == "union" and
		output:Get(1):HasType("tuple")
	then
		output = output:Get(1)
	end

	if output.Type == "union" then
		-- typically a function with mutliple uncertain returns
		for _, obj in ipairs(output:GetData()) do
			if obj.Type ~= "tuple" then
				-- if the function returns one value it's not in a tuple
				obj = Tuple({obj})
			end

			-- check each tuple in the union
			check_output(self, obj, original_contract)
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
			if output.Type == "tuple" and output:GetLength() == 1 then
				local val = output:GetFirstValue()

				if val.Type == "union" and val:GetLength() == 0 then return end
			end

			local ok, reason, a, b, i = output:IsSubsetOfTuple(output_signature)

			if not ok then self:Error(reason) end
		end
	end
end

return function(META)
	function META:CallBodyFunction(obj, input)
		local function_node = obj:GetFunctionBodyNode()
		local is_type_function = function_node.kind == "local_type_function" or
			function_node.kind == "type_function"

		do
			local ok, err = check_input(self, obj, input)

			if not ok then return ok, err end
		end

		-- crawl the function with the new arguments
		-- return_result is either a union of tuples or a single tuple
		local scope = self:CreateAndPushFunctionScope(obj)
		self:PushTruthyExpressionContext(false)
		self:PushFalsyExpressionContext(false)
		self:PushGlobalEnvironment(
			function_node,
			self:GetDefaultEnvironment(self:GetCurrentAnalyzerEnvironment()),
			self:GetCurrentAnalyzerEnvironment()
		)

		if function_node.self_call then
			self:CreateLocalValue("self", input:Get(1) or Nil())
		end

		for i, identifier in ipairs(function_node.identifiers) do
			local argi = function_node.self_call and (i + 1) or i

			if self:IsTypesystem() then
				self:CreateLocalValue(identifier.value.value, input:GetWithoutExpansion(argi))
			end

			if self:IsRuntime() then
				if identifier.value.value == "..." then
					self:CreateLocalValue(identifier.value.value, input:Slice(argi))
				else
					self:CreateLocalValue(identifier.value.value, input:Get(argi) or Nil())
				end
			end
		end

		if is_type_function then self:PushAnalyzerEnvironment("typesystem") end

		local output = self:AnalyzeStatementsAndCollectOutputSignatures(function_node)

		if is_type_function then self:PopAnalyzerEnvironment() end

		self:PopGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
		self:PopScope()
		self:PopFalsyExpressionContext()
		self:PopTruthyExpressionContext()

		if scope.TrackedObjects then
			for _, obj in ipairs(scope.TrackedObjects) do
				if obj.Type == "upvalue" then
					for i = #obj.mutations, 1, -1 do
						local mut = obj.mutations[i]

						if mut.from_tracking then table.remove(obj.mutations, i) end
					end
				else
					for _, mutations in pairs(obj.mutations) do
						for i = #mutations, 1, -1 do
							local mut = mutations[i]

							if mut.from_tracking then table.remove(mutations, i) end
						end
					end
				end
			end
		end

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
							self:Warning("argument is untyped")
						end
					elseif
						function_node.identifiers[i] and
						not function_node.identifiers[i].type_expression
					then
						self:Warning("argument is untyped")
					end
				end
			end

			obj:GetInputSignature():Merge(input:Slice(1, obj:GetInputSignature():GetMinimumLength()))
		end

		do -- this is for the emitter
			if function_node.identifiers then
				for i, node in ipairs(function_node.identifiers) do
					node:AddType(obj:GetInputSignature():Get(i))
				end
			end

			function_node:AddType(obj)
		end

		local output_signature = obj:IsExplicitOutputSignature() and obj:GetOutputSignature()

		-- if the function has return type annotations, analyze them and use it as contract
		if not output_signature and function_node.return_types and self:IsRuntime() then
			self:CreateAndPushFunctionScope(obj)
			self:PushAnalyzerEnvironment("typesystem")

			for i, key in ipairs(function_node.identifiers) do
				if function_node.self_call then i = i + 1 end

				self:CreateLocalValue(key.value.value, input:Get(i))
			end

			output_signature = Tuple(self:AnalyzeExpressions(function_node.return_types))
			self:PopAnalyzerEnvironment()
			self:PopScope()
		end

		if not output_signature then
			-- if there is no return type 
			if self:IsRuntime() then
				local copy

				for i, v in ipairs(output:GetData()) do
					if v.Type == "table" and not v:GetContract() then
						copy = copy or output:Copy()
						local tbl = Table()

						for _, kv in ipairs(v:GetData()) do
							tbl:Set(kv.key, self:GetMutatedTableValue(v, kv.key, kv.val))
						end

						copy:Set(i, tbl)
					end
				end

				obj:GetOutputSignature():Merge(copy or output)
			end

			return output
		end

		-- check against the function's return type
		check_output(self, output, output_signature)

		if self:IsTypesystem() then return output end

		local contract = obj:GetOutputSignature():Copy()

		for _, v in ipairs(contract:GetData()) do
			if v.Type == "table" then v:SetReferenceId(nil) end
		end

		-- if a return type is marked with ref, it will pass the ref value back to the caller
		-- a bit like generics
		for i, v in ipairs(output_signature:GetData()) do
			if v.ref_argument then contract:Set(i, output:Get(i)) end
		end

		return contract
	end
end
