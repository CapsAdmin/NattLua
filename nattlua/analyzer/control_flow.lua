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
	
	function META:ThrowSilentError(assert_expression)
		if assert_expression and assert_expression:IsCertainlyTrue() then
			return
		end

		for i = #self.call_stack, 1, -1 do
			local frame = self.call_stack[i]
			local function_scope = frame.scope:GetNearestFunctionScope()

			if not assert_expression or assert_expression:IsCertainlyTrue() then
				function_scope.lua_silent_error = function_scope.lua_silent_error or {}
				table.insert(function_scope.lua_silent_error, 1, self:GetScope())
				frame.scope:UncertainReturn()
			end

			if assert_expression and assert_expression:IsTruthy() then
				-- track the assertion expression
				local upvalues

				if frame.scope:GetTrackedUpvalues() then
					upvalues = {}

					for _, a in ipairs(frame.scope:GetTrackedUpvalues()) do
						for _, b in ipairs(self:GetTrackedUpvalues()) do
							if a.upvalue == b.upvalue then
								table.insert(upvalues, a)
							end
						end
					end
				end

				local tables

				if frame.scope:GetTrackedTables() then
					tables = {}

					for _, a in ipairs(frame.scope:GetTrackedTables()) do
						for _, b in ipairs(self:GetTrackedTables()) do
							if a.obj == b.obj then
								table.insert(tables, a)
							end
						end
					end
				end
				
				self:ApplyMutationsAfterReturn(frame.scope, frame.scope, true, upvalues, tables)
				return
			end

				self:ApplyMutationsAfterReturn(
					frame.scope,
					function_scope,
					true,
					frame.scope:GetTrackedUpvalues(),
					frame.scope:GetTrackedTables()
				)
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

			self:ApplyMutationsAfterReturn(self:GetScope(), nil, false, self:GetTrackedUpvalues(old), self:GetTrackedTables())
		else
			self.lua_error_thrown = msg
		end

		if not no_report then
			self:Error(self.current_statement, msg)
		end
	end

	function META:GetThrownErrorMessage()
			return self.lua_error_thrown or
				self.lua_assert_error_thrown and
				self.lua_assert_error_thrown.msg
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
			if scope:IsElseConditionalScope() then
				function_scope.uncertain_function_return = false
				function_scope:CertainReturn()
			end
		elseif function_scope.uncertain_function_return then
			function_scope.uncertain_function_return = false
		end

		local thrown = false
		
		if function_scope.lua_silent_error then 
			local errored_scope = table.remove(function_scope.lua_silent_error)

				if
					errored_scope and
					self:GetScope():IsCertainFromScope(errored_scope)
					and
					errored_scope:IsCertain()
				then
				thrown = true
			end
		end 

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
		
		self:ApplyMutationsAfterReturn(scope, function_scope, true, scope:GetTrackedUpvalues(), scope:GetTrackedTables())
	end

	function META:Print(...)
		local helpers = require("nattlua.other.helpers")
		local node = self.current_expression
		local start, stop = node:GetStartStop()

		do
			local node = self.current_statement
			local start2, stop2 = node:GetStartStop()

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

	function META:PushConditionalScope(statement, truthy, falsy)
		local scope = self:CreateAndPushScope()
		scope:SetConditionalScope(true)
		scope:SetStatement(statement)
		scope:SetTruthy(truthy)
		scope:SetFalsy(falsy)
		return scope
	end

	function META:ErrorAndCloneCurrentScope(node, err)
		self:Error(node, err)
		self:CloneCurrentScope()
		self:GetScope():SetConditionalScope(true)
	end

	function META:PopConditionalScope()
		self:PopScope()
	end
end
