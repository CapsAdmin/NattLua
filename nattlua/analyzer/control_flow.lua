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

		if statements[1] then
			self:GetScope().missing_return = statements[#statements].kind ~= "return"
		else
			self:GetScope().missing_return = true
		end
	end

	function META:AnalyzeStatementsAndCollectReturnTypes(statement)
		local scope = self:GetScope()
		scope:MakeFunctionScope(statement)
		self:AnalyzeStatements(statement.statements)

		if scope.missing_return and self:IsMaybeReachable() then
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

	function META:MutateTracked(scope, scope_override, negate, upvalues, objects)
		if objects then
			for _, v in ipairs(objects) do
				local val
				if scope:IsPartOfElseStatement() or v.inverted then
					val = negate and v.falsy or v.truthy
				else
					val = negate and v.truthy or v.falsy
				end

				if val and (val.Type ~= "union" or not val:IsEmpty()) then
					if #val:GetData() == 1 then
						val = val:GetData()[1]
					end	 
	
					self:MutateValue(v.obj, v.key, val, scope_override)
				end
			end
		end

		if upvalues then
			for u, v in pairs(upvalues) do
				local val
				if scope:IsPartOfElseStatement() or v[#v].inverted then
					val = negate and v[#v].falsy or v[#v].truthy
				else
					val = negate and v[#v].truthy or v[#v].falsy
				end

				if val and (val.Type ~= "union" or not val:IsEmpty()) then
					if #val:GetData() == 1 then
						val = val:GetData()[1]
					end

					self:MutateUpvalue(u, val, scope_override)
				end
			end
		end
	end
	
	function META:ThrowSilentError()
		for i = #self.call_stack, 1, -1 do
			local frame = self.call_stack[i]
			local function_scope = frame.scope:GetNearestFunctionScope()
			function_scope.lua_silent_error = function_scope.lua_silent_error or {}
			table.insert(function_scope.lua_silent_error, 1, self:GetScope())
			frame.scope:UncertainReturn()
			
			self:MutateTracked(frame.scope, frame.scope, false, frame.scope:GetTrackedObjects())
		end
	end

	function META:ThrowError(msg, obj, no_report)
		if obj then

			-- track "if x then" which has no binary or prefix operators
			self:TrackUpvalue(obj)

			self.lua_assert_error_thrown = {msg = msg, obj = obj,}

			if obj:IsTruthy() then
				self:GetScope():UncertainReturn()
			else
				self:GetScope():CertainReturn()
			end

			local old = {}
			for i, upvalue in ipairs(self:GetScope().upvalues.runtime.list) do
				old[i] = upvalue
			end

			local copy = self:CloneCurrentScope()
			copy:SetTestCondition(obj)

			self:MutateTracked(copy, nil, true, self:GetTrackedObjectMap(old))
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

		local thrown = false
		
		if function_scope.lua_silent_error then 
			local errored_scope = table.remove(function_scope.lua_silent_error)
			if errored_scope and self:GetScope():IsCertain(errored_scope) and errored_scope:IsCertain() then
				thrown = true
			end
		end 

		function_scope:SetCanThrow(thrown)

		if not thrown then
			scope:CollectReturnTypes(node, types)
		end

		if scope:IsUncertain() then
			function_scope:UncertainReturn()
			scope:UncertainReturn()
		else
			function_scope:CertainReturn(self)
			scope:CertainReturn(self)
		end

		self:MutateTracked(scope, function_scope, false, scope:GetTrackedObjects())
	end

	function META:Print(...)
		local helpers = require("nattlua.other.helpers")
		
		local node = self.current_expression
		local start, stop = helpers.LazyFindStartStop(node)

		do
			local node = self.current_statement
			local start2, stop2 = helpers.LazyFindStartStop(node)
			if start2 > start then
				start = start2
				stop = stop2
			end
		end

		local str = {}
		for i = 1, select("#", ...) do
			str[i] = tostring(select(i, ...))
		end
		print(helpers.FormatError(node.Code, table.concat(str, ", "), start, stop, 1))
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
