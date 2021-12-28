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
				return
			end

			if self:GetScope():DidCertainReturn() then
				self:GetScope():ClearCertainReturn()
				return
			end
		end

		if self:GetScope().uncertain_function_return == nil then
			self:GetScope().uncertain_function_return = false
		end
	end

	function META:AnalyzeStatementsAndCollectReturnTypes(statement)
		local scope = self:GetScope()
		scope:MakeFunctionScope(statement)
		self:AnalyzeStatements(statement.statements)

		if scope.uncertain_function_return or #scope:GetReturnTypes() == 0 then
			self:Return(statement, {Nil():SetNode(statement)})
		end

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


		scope:ClearCertainReturnTypes()

		if #union:GetData() == 1 then return union:GetData()[1] end
		
		return union
	end
	
	function META:ThrowSilentError()
		self:UncertainReturn()
		self.lua_silent_error = self:GetScope()
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

	function META:GetThrownErrorMessage()
		return self.lua_error_thrown or self.lua_assert_error_thrown and self.lua_assert_error_thrown.msg
	end

	function META:ClearError()
		self.lua_error_thrown = nil
		self.lua_assert_error_thrown = nil
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
				function_scope:CertainReturn()
			end
		elseif function_scope.uncertain_function_return then
			function_scope.uncertain_function_return = false
		end

		local thrown = self.lua_silent_error == self:GetScope()
		self.lua_silent_error = nil

		if not thrown then
			scope:CollectReturnTypes(node, types)
		end

		if scope:IsUncertain() then
			function_scope:UncertainReturn(self)
			scope:UncertainReturn(self)
		else
			function_scope:CertainReturn(self)
			scope:CertainReturn(self)
		end
	end

	function META:PushConditionalScope(statement, condition)
		local scope = self:CreateAndPushScope()
		scope:SetTestCondition(condition)
		scope:SetStatement(statement)
		scope:MakeUncertain(condition:IsUncertain())
	end

	function META:ErrorAndCloneCurrentScope(node, err, condition)
		self:Error(node, err)
		self:CloneCurrentScope()
		self:GetScope():SetTestCondition(condition)
	end

	function META:PopConditionalScope()
		self:PopScope()
	end
end
