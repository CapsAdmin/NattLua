local ipairs = ipairs
local type = type
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Nil = require("nattlua.types.symbol").Nil
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union

-- this turns out to be really hard so I'm trying 
-- naive approaches while writing tests

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
			if #ret.types == 1 then
				union:AddType(ret.types[1])
			else
				local tup = Tuple(ret.types)
				tup:SetNode(ret.node)
				union:AddType(tup)
			end
		end

		if scope.uncertain_function_return or #scope:GetReturnTypes() == 0 then
			union:AddType(Nil():SetNode(statement))
		end

		scope:ClearCertainReturnTypes()

		if #union:GetData() == 1 then return union:GetData()[1] end
		
		return union
	end

	function META:ThrowError(msg, obj, no_report)
		if obj then
			self.lua_assert_error_thrown = {msg = msg, obj = obj,}

			if obj:IsTruthy() then
				self:GetScope():UncertainReturn(self)
			else
				self:GetScope():CertainReturn(self)
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

		scope:CollectReturnTypes(node, types)

		if scope:IsUncertain() then
			scope:UncertainReturn(self)
		else
			scope:CertainReturn(self)
		end
	end

	function META:OnEnterNumericForLoop(scope, init, max)
		scope:MakeUncertain(not init:IsLiteral() or not max:IsLiteral())
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
