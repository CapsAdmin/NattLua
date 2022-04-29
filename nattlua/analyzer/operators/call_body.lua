local ipairs = ipairs
local table = _G.table
local type_errors = require("nattlua.types.error_messages")
local Tuple = require("nattlua.types.tuple").Tuple
local Table = require("nattlua.types.table").Table
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any

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

local function check_and_setup_arguments(self, arguments, contracts, function_node, obj)
	local len = contracts:GetSafeLength(arguments)
	local contract_override = {}

	if function_node.identifiers[1] then -- analyze the type expressions
		self:CreateAndPushFunctionScope(obj)
		self:PushAnalyzerEnvironment("typesystem")
		local args = {}

		for i = 1, len do
			local key = function_node.identifiers[i] or
				function_node.identifiers[#function_node.identifiers]

			if function_node.self_call then i = i + 1 end

			-- stem type so that we can allow
			-- function(x: foo<|x|>): nil
			self:CreateLocalValue(key.value.value, Any())
			local arg
			local contract
			arg = arguments:Get(i)

			if key.value.value == "..." then
				contract = contracts:GetWithoutExpansion(i)
			else
				contract = contracts:Get(i)
			end

			if not arg then
				arg = Nil()
				arguments:Set(i, arg)
			end

			local ref_callback = arg and
				contract and
				contract.ref_argument and
				contract.Type == "function" and
				arg.Type == "function" and
				not arg.arguments_inferred

			if contract and contract.ref_argument and arg and not ref_callback then
				self:CreateLocalValue(key.value.value, arg)
			end

			if key.type_expression then
				args[i] = self:AnalyzeExpression(key.type_expression):GetFirstValue()
			end

			if contract and contract.ref_argument and arg and not ref_callback then
				args[i] = arg
				args[i].ref_argument = true
				local ok, err = args[i]:IsSubsetOf(contract)

				if not ok then
					return type_errors.other({"argument #", i, " ", arg, ": ", err})
				end
			elseif args[i] then
				self:CreateLocalValue(key.value.value, args[i])
			end

			if not self.processing_deferred_calls then
				if contract and contract.literal_argument and arg and not arg:IsLiteral() then
					return type_errors.other({"argument #", i, " ", arg, ": not literal"})
				end
			end
		end

		self:PopAnalyzerEnvironment()
		self:PopScope()
		contract_override = args
	end

	do -- coerce untyped functions to contract callbacks
		for i, arg in ipairs(arguments:GetData()) do
			if arg.Type == "function" then
				local func = arg

				if
					contract_override[i] and
					contract_override[i].Type == "union" and
					not contract_override[i].ref_argument
				then
					local merged = contract_override[i]:ShrinkToFunctionSignature()

					if merged then
						func:SetArguments(merged:GetArguments())
						func:SetReturnTypes(merged:GetReturnTypes())
					end
				else
					if not func.explicit_arguments then
						local contract = contract_override[i] or obj:GetArguments():Get(i)

						if contract then
							if contract.Type == "union" then
								local tup = Tuple({})

								for _, func in ipairs(contract:GetData()) do
									tup:Merge(func:GetArguments())
									func:SetArguments(tup)
								end

								func.arguments_inferred = true
							elseif contract.Type == "function" then
								func:SetArguments(contract:GetArguments():Copy(nil, true)) -- force copy tables so we don't mutate the contract
								func.arguments_inferred = true
							end
						end
					end

					if not func.explicit_return then
						local contract = contract_override[i] or obj:GetReturnTypes():Get(i)

						if contract then
							if contract.Type == "union" then
								local tup = Tuple({})

								for _, func in ipairs(contract:GetData()) do
									tup:Merge(func:GetReturnTypes())
								end

								func:SetReturnTypes(tup)
							elseif contract.Type == "function" then
								func:SetReturnTypes(contract:GetReturnTypes())
							end
						end
					end
				end
			end
		end
	end

	for i = 1, len do
		local arg = arguments:Get(i)
		local contract = contract_override[i] or contracts:Get(i)
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
			if contract.Type == "union" then
				local shrunk = contract:ShrinkToFunctionSignature()

				if shrunk then contract = contract:ShrinkToFunctionSignature() end
			end

			if arg.Type == "function" and contract.Type == "function" then
				ok, reason = arg:IsCallbackSubsetOf(contract)
			else
				ok, reason = arg:IsSubsetOf(contract)
			end
		end

		if not ok then
			restore_mutated_types(self)
			return type_errors.other({"argument #", i, " ", arg, ": ", reason})
		end

		if
			arg.Type == "table" and
			contract.Type == "table" and
			arg:GetUpvalue() and
			not contract.ref_argument
		then
			mutate_type(self, i, arg, contract, arguments)
		else
			-- if it's a literal argument we pass the incoming value
			if not contract.ref_argument then
				local t = contract:Copy()
				t:SetContract(contract)
				arguments:Set(i, t)
			end
		end
	end

	return true
end

local function check_return_result(self, result, contract)
	if self:IsTypesystem() then
		-- in the typesystem we must not unpack tuples when checking
		local ok, reason, a, b, i = result:IsSubsetOfTupleWithoutExpansion(contract)

		if not ok then
			local _, err = type_errors.subset(a, b, {"return #", i, " '", b, "': ", reason})
			self:Error(err)
		end

		return
	end

	local original_contract = contract

	if
		contract:GetLength() == 1 and
		contract:Get(1).Type == "union" and
		contract:Get(1):HasType("tuple")
	then
		contract = contract:Get(1)
	end

	if
		result.Type == "tuple" and
		result:GetLength() == 1 and
		result:Get(1) and
		result:Get(1).Type == "union" and
		result:Get(1):HasType("tuple")
	then
		result = result:Get(1)
	end

	if result.Type == "union" then
		-- typically a function with mutliple uncertain returns
		for _, obj in ipairs(result:GetData()) do
			if obj.Type ~= "tuple" then
				-- if the function returns one value it's not in a tuple
				obj = Tuple({obj})
			end

			-- check each tuple in the union
			check_return_result(self, obj, original_contract)
		end
	else
		if contract.Type == "union" then
			local errors = {}

			for _, contract in ipairs(contract:GetData()) do
				local ok, reason = result:IsSubsetOfTuple(contract)

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
			if result.Type == "tuple" and result:GetLength() == 1 then
				local val = result:GetFirstValue()

				if val.Type == "union" and val:GetLength() == 0 then return end
			end

			local ok, reason, a, b, i = result:IsSubsetOfTuple(contract)

			if not ok then self:Error(reason) end
		end
	end
end

return function(META)
    function META:AnalyzeFunctionBody(obj, function_node, arguments)
        local scope = self:CreateAndPushFunctionScope(obj)
        self:PushTruthyExpressionContext(false)
        self:PushFalsyExpressionContext(false)
        self:PushGlobalEnvironment(
            function_node,
            self:GetDefaultEnvironment(self:GetCurrentAnalyzerEnvironment()),
            self:GetCurrentAnalyzerEnvironment()
        )

        if function_node.self_call then
            self:CreateLocalValue("self", arguments:Get(1) or Nil())
        end

        for i, identifier in ipairs(function_node.identifiers) do
            local argi = function_node.self_call and (i + 1) or i

            if self:IsTypesystem() then
                self:CreateLocalValue(identifier.value.value, arguments:GetWithoutExpansion(argi))
            end

            if self:IsRuntime() then
                if identifier.value.value == "..." then
                    self:CreateLocalValue(identifier.value.value, arguments:Slice(argi))
                else
                    self:CreateLocalValue(identifier.value.value, arguments:Get(argi) or Nil())
                end
            end
        end

        if
            function_node.kind == "local_type_function" or
            function_node.kind == "type_function"
        then
            self:PushAnalyzerEnvironment("typesystem")
        end

        local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)

        if
            function_node.kind == "local_type_function" or
            function_node.kind == "type_function"
        then
            self:PopAnalyzerEnvironment()
        end

        self:PopGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
        local function_scope = self:PopScope()
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

        if analyzed_return.Type ~= "tuple" then
            return Tuple({analyzed_return}), scope
        end

        return analyzed_return, scope
    end

    function META:CallBodyFunction(obj, arguments, function_node)
        if obj:HasExplicitArguments() or function_node.identifiers_typesystem then
            if
                function_node.kind == "local_type_function" or
                function_node.kind == "type_function"
            then
                if function_node.identifiers_typesystem then
                    local call_expression = self:GetCallStack()[1].call_node

                    for i, key in ipairs(function_node.identifiers) do
                        if function_node.self_call then i = i + 1 end

                        local arg = arguments:Get(i)
                        local generic_upvalue = function_node.identifiers_typesystem and
                            function_node.identifiers_typesystem[i] or
                            nil
                        local generic_type = call_expression.expressions_typesystem and
                            call_expression.expressions_typesystem[i] or
                            nil

                        if generic_upvalue then
                            local T = self:AnalyzeExpression(generic_type)
                            self:CreateLocalValue(generic_upvalue.value.value, T)
                        end
                    end

                    local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments(), function_node, obj)

                    if not ok then return ok, err end
                end

                -- otherwise if we're a analyzer function we just do a simple check and arguments are passed as is
                -- local type foo(T: any) return T end
                -- T becomes the type that is passed in, and not "any"
                -- it's the equivalent of function foo<T extends any>(val: T) { return val }
                local ok, reason, a, b, i = arguments:IsSubsetOfTupleWithoutExpansion(obj:GetArguments())

                if not ok then
                    return type_errors.subset(a, b, {"argument #", i, " - ", reason})
                end
            elseif self:IsRuntime() then
                -- if we have explicit arguments, we need to do a complex check against the contract
                -- this might mutate the arguments
                local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments(), function_node, obj)

                if not ok then return ok, err end
            end
        end

        -- crawl the function with the new arguments
        -- return_result is either a union of tuples or a single tuple
        local return_result, scope = self:AnalyzeFunctionBody(obj, function_node, arguments)
        restore_mutated_types(self)
        -- used for analyzing side effects
        obj:AddScope(arguments, return_result, scope)

        if not obj:HasExplicitArguments() then
            if not obj.arguments_inferred and function_node.identifiers then
                for i in ipairs(obj:GetArguments():GetData()) do
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

            obj:GetArguments():Merge(arguments:Slice(1, obj:GetArguments():GetMinimumLength()))
        end

        do -- this is for the emitter
            if function_node.identifiers then
                for i, node in ipairs(function_node.identifiers) do
                    node:AddType(obj:GetArguments():Get(i))
                end
            end

            function_node:AddType(obj)
        end

        local return_contract = obj:HasExplicitReturnTypes() and obj:GetReturnTypes()

        -- if the function has return type annotations, analyze them and use it as contract
        if not return_contract and function_node.return_types and self:IsRuntime() then
            self:CreateAndPushFunctionScope(obj)
            self:PushAnalyzerEnvironment("typesystem")

            for i, key in ipairs(function_node.identifiers) do
                if function_node.self_call then i = i + 1 end

                self:CreateLocalValue(key.value.value, arguments:Get(i))
            end

            return_contract = Tuple(self:AnalyzeExpressions(function_node.return_types))
            self:PopAnalyzerEnvironment()
            self:PopScope()
        end

        if not return_contract then
            -- if there is no return type 
            if self:IsRuntime() then
                local copy

                for i, v in ipairs(return_result:GetData()) do
                    if v.Type == "table" and not v:GetContract() then
                        copy = copy or return_result:Copy()
                        local tbl = Table()

                        for _, kv in ipairs(v:GetData()) do
                            tbl:Set(kv.key, self:GetMutatedTableValue(v, kv.key, kv.val))
                        end

                        copy:Set(i, tbl)
                    end
                end

                obj:GetReturnTypes():Merge(copy or return_result)
            end

            return return_result
        end

        -- check against the function's return type
        check_return_result(self, return_result, return_contract)

        if self:IsTypesystem() then return return_result end

        local contract = obj:GetReturnTypes():Copy()

        for _, v in ipairs(contract:GetData()) do
            if v.Type == "table" then v:SetReferenceId(nil) end
        end

        -- if a return type is marked with literal, it will pass the literal value back to the caller
        -- a bit like generics
        for i, v in ipairs(return_contract:GetData()) do
            if v.ref_argument then contract:Set(i, return_result:Get(i)) end
        end

        return contract
    end
end