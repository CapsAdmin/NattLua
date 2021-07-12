local ipairs = ipairs
local type = type
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Nil = require("nattlua.types.symbol").Nil
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local MutationTracker = require("nattlua.analyzer.base.mutation_tracker")

-- this turns out to be really hard so I'm trying 
-- naive approaches while writing tests

local function cast(val)
	if type(val) == "string" then
		return LString(val)
	elseif type(val) == "number" then
		return LNumber(val)
	end

	return val
end

return function(META)
	function META:AnalyzeStatements(statements)
		for _, statement in ipairs(statements) do
			self:AnalyzeStatement(statement)

			if self.break_out_scope or self._continue_ then
				self:FireEvent(self.break_out_scope and "break" or "continue")

				break
			end

			if self:GetScope():DidCertainReturn() then
				self:GetScope():ClearCertainReturn()

				break
			end
		end
	end

	function META:AnalyzeStatementsAndCollectReturnTypes(statement)
		local scope = self:GetScope()
		scope:MakeFunctionScope()
		self:AnalyzeStatements(statement.statements)
		local union = Union({})

		for _, ret in ipairs(scope:GetReturnTypes()) do
			local tup = Tuple(ret.types)
			tup:SetNode(ret.node)
			union:AddType(tup)
		end

		if scope.uncertain_function_return or #scope:GetReturnTypes() == 0 then
			local tup = Tuple({Nil()})
			tup:SetNode(statement)
			union:AddType(tup)
		end

		scope:ClearCertainReturnTypes()
		if #union:GetData() == 1 then return union:GetData()[1] end
		return union
	end

	function META:ThrowError(msg, obj, no_report)
		if obj then
			self.lua_assert_error_thrown = {msg = msg, obj = obj,}
			if obj:IsTruthy() then
				self:GetScope():UncertainReturn()
			else
				self:GetScope():CertainReturn()
			end
			local copy = self:CloneCurrentScope()
			copy:SetTestCondition(obj)
		else
			self.lua_error_thrown = msg
		end

		if not no_report then
			self:Error(self.current_statement, msg)
		end
	end

	function META:Return(node, types)
		local scope = self:GetScope()

		if not scope:IsReadOnly() then
			local function_scope = scope:GetNearestFunctionScope()

			if scope == function_scope then
                -- the root scope of the function when being called is definetly certain
                function_scope.uncertain_function_return = false
			elseif scope:IsUncertain() then
				function_scope.uncertain_function_return = true
                
                -- else always hits, so even if the else part is uncertain
                -- it does mean that this function at least returns something
                if scope:IsPartOfElseStatement() then
					function_scope.uncertain_function_return = false
				end
			elseif function_scope.uncertain_function_return then
				function_scope.uncertain_function_return = false
			end
		end

		scope:CollectReturnTypes(node, types)

		if scope:IsUncertain() then
			scope:UncertainReturn()
		else
			scope:CertainReturn()
		end
	end

	function META:OnEnterNumericForLoop(scope, init, max)
		scope:MakeUncertain(not init:IsLiteral() or not max:IsLiteral())
	end

	local function cast_key(key)
		if type(key) == "string" then return key end

		if type(key) == "table" then
			if key.type == "expression" and key.kind == "value" then
				return key.value.value
			elseif key.type == "letter" then
				return key.value
			elseif key.Type == "string" and key:IsLiteral() then
				return key:GetData()
			elseif key.Type == "number" and key:IsLiteral() then
				return key:GetData()
			end
		end
	end

	local function initialize_mutation_tracker(obj, scope, key, env)
		obj.mutations = obj.mutations or {}
		obj.mutations[key] = obj.mutations[key] or MutationTracker()

		if not obj.mutations[key]:HasMutations() then
			if obj.Type == "table" then
				local val = (obj:GetContract() or obj):Get(cast(key)) or Nil()
				val:SetUpvalue(obj.mutations[key])
				val:SetUpvalueReference(key)
				obj.mutations[key]:Mutate(val, scope:GetRoot())
			end
		end
	end

	function META:GetMutatedValue(obj, key, value, env)
		if env == "typesystem" then return end
		local scope = self:GetScope()
		if scope:IsReadOnly() then return value end
		key = cast_key(key)
		if not key then return value end
		initialize_mutation_tracker(obj, scope, key, env)
		return obj.mutations[key]:GetValueFromScope(scope, obj, key, self) or value
	end

	function META:OnEnterConditionalScope(data)
		local scope = self:GetScope()
		scope:SetTestCondition(data.condition, data)
		scope:MakeUncertain(data.condition:IsUncertain())
	end

	function META:ErrorAndCloneCurrentScope(node, err, condition)
		self:Error(node, err)
		self:CloneCurrentScope()
		self:GetScope():SetTestCondition(condition)
	end

	function META:MutateValue(obj, key, val, env)
		if env == "typesystem" then return end
		local scope = self:GetScope()
		if scope:IsReadOnly() then return end
		key = cast_key(key)
		if not key then return end -- no mutation?
        
		if obj.Type == "upvalue" then
			val:SetUpvalue(obj)
			val:SetUpvalueReference(key)
		end

		initialize_mutation_tracker(obj, scope, key, env)
		obj.mutations[key]:Mutate(val, scope)
	end

	function META:OnExitConditionalScope()
		local exited_scope = self:GetLastScope()
		local current_scope = self:GetScope()

		if
			current_scope:DidCertainReturn() or
			self.lua_error_thrown or
			self.lua_assert_error_thrown
		then
			current_scope:MakeUncertain(exited_scope:IsUncertain())

			if exited_scope:IsUncertain() then
				local copy = self:CloneCurrentScope()
				copy:SetTestCondition(exited_scope:GetTestCondition())
			end

			self.lua_assert_error_thrown = nil
			self.lua_error_thrown = nil
		end
	end
end
