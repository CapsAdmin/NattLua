local ipairs = ipairs
local table_remove = _G.table.remove
local table_insert = _G.table.insert
local Any = require("nattlua.types.any").Any
local Nil = require("nattlua.types.symbol").Nil
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local math_huge = math.huge
local error_messages = require("nattlua.error_messages")
local debug_getinfo = _G.debug.getinfo
-- this turns out to be really hard so I'm trying 
-- naive approaches while writing tests
return function(META--[[#: any]])
	META:AddInitializer(function(self)
		self.call_stack_map = {}
		self.recursively_called = {}
	end)

	function META:AnalyzeStatements(statements)
		for _, statement in ipairs(statements) do
			self:AnalyzeStatement(statement)

			if self:DidCertainBreak() then break end

			if self._continue_ then return end

			if self:GetScope():DidCertainReturn() then
				self:GetScope():ClearCertainReturn()
				return
			end
		end

		if self:GetScope().uncertain_function_return == nil then
			self:GetScope().uncertain_function_return = false
		end

		if statements[1] then
			self:GetScope().missing_return = statements[#statements].Type ~= "statement_return"
		else
			self:GetScope().missing_return = true
		end
	end

	do
		local push_break_state, get_break_state, get_offset, pop_break_state = META:SetupContextValue("break_state")
		local push_break_uncertainty, get_break_uncertainty, pop_break_uncertainty = META:SetupContextValue("break_uncertainty")

		-- Enhanced Break function using context management
		function META:Break()
			local scope = self:GetScope()
			local loop_scope = scope:GetNearestLoopScope()
			-- Use context system to track break states
			local break_state = {
				break_scope = scope,
				loop_scope = loop_scope,
				is_certain = scope:IsCertain(),
				is_uncertain = scope:IsUncertain(),
			}
			push_break_state(self, break_state)
			self:PushScope(loop_scope)
			self:ApplyMutationsAfterStatement(scope, true, scope:GetTrackedUpvalues(), scope:GetTrackedTables())
			self:PopScope()
		end

		function META:DidCertainBreak()
			local break_state = get_break_state(self)
			return break_state and break_state.is_certain or false
		end

		function META:DidUncertainBreak()
			local break_state = get_break_state(self)
			return break_state and break_state.is_uncertain or false
		end

		-- Get the current break scope (for debugging/inspection)
		function META:GetBreakScope()
			local break_state = get_break_state(self)
			return break_state and break_state.break_scope or nil
		end

		function META:ClearBreak()
			if get_break_state(self) then pop_break_state(self) end
		end

		-- Enhanced uncertainty management using context system
		function META:PushBreakUncertainty(loop_scope, is_uncertain)
			local uncertainty_state = {
				loop_scope = loop_scope,
				is_uncertain = is_uncertain,
				previous_uncertain = self:IsInBreakUncertainty(),
			}
			push_break_uncertainty(self, uncertainty_state)
		end

		function META:PopBreakUncertainty()
			if get_break_uncertainty(self) then pop_break_uncertainty(self) end
		end

		function META:IsInBreakUncertainty(target_scope)
			local uncertainty_state = get_break_uncertainty(self)

			if not uncertainty_state then return false end

			if target_scope then
				return uncertainty_state.loop_scope == target_scope and uncertainty_state.is_uncertain
			end

			return uncertainty_state.is_uncertain
		end

		-- Enhanced loop entry using existing patterns
		function META:EnterLoop(statement, condition_obj)
			local loop_scope = self:PushConditionalScope(
				statement,
				condition_obj and condition_obj:IsTruthy() or nil,
				condition_obj and condition_obj:IsFalsy() or nil
			)
			loop_scope:SetLoopScope(true)
			-- Use existing uncertain loop context management but enhance it
			local has_uncertain_condition = condition_obj and condition_obj:IsTruthy() and condition_obj:IsFalsy()
			local has_uncertain_break = self:DidUncertainBreak()

			if has_uncertain_condition or has_uncertain_break then
				self:PushUncertainLoop(loop_scope)
				self:PushBreakUncertainty(loop_scope, true)
			else
				self:PushUncertainLoop(false)
				self:PushBreakUncertainty(loop_scope, false)
			end

			return loop_scope
		end

		-- Enhanced loop exit using existing patterns
		function META:ExitLoop(loop_scope)
			self:PopBreakUncertainty()
			self:PopUncertainLoop()
			self:PopConditionalScope()
			-- Clear any breaks that were resolved by this loop level
			local break_state = get_break_state(self)

			if break_state and break_state.loop_scope == loop_scope then
				self:ClearBreak()
			end
		end

		-- Enhanced widening that works with context system
		function META:WidenForUncertainty(obj, loop_scope)
			if
				self:IsInBreakUncertainty(loop_scope) or
				self:IsInUncertainLoop(loop_scope) or
				self:DidUncertainBreak()
			then
				return obj:Widen()
			end

			return obj
		end

		-- Enhanced break checking that respects loop boundaries
		function META:DidBreakForLoop(loop_scope)
			local break_state = get_break_state(self)

			if not break_state then return false, false end

			-- Check if the break applies to this specific loop
			local applies_to_loop = break_state.loop_scope == loop_scope or
				loop_scope:Contains(break_state.loop_scope)

			if not applies_to_loop then return false, false end

			return break_state.is_certain, break_state.is_uncertain
		end

		-- Helper to check if we should continue loop iteration
		function META:ShouldContinueLoop(loop_scope)
			local certain_break, uncertain_break = self:DidBreakForLoop(loop_scope)

			if certain_break then return false, "certain_break" end

			if uncertain_break then return false, "uncertain_break" end

			if self:GetScope():DidCertainReturn() then
				return false, "certain_return"
			end

			if self:GetScope():DidUncertainReturn() then
				return false, "uncertain_return"
			end

			return true, nil
		end

		-- Context-aware break state management for nested loops
		function META:PushLoopContext(statement, condition_obj)
			-- Save the current break state before entering nested context
			local current_break = get_break_state(self)

			--	self:PushContextRef("saved_break_state", current_break)
			-- Clear break state for the new loop level
			if current_break then pop_break_state(self) end

			return self:EnterLoop(statement, condition_obj)
		end

		function META:PopLoopContext(loop_scope)
			self:ExitLoop(loop_scope)

			do
				return
			end

			-- Restore any saved break state from outer loops
			local saved_break = self:GetContextValue("saved_break_state")

			if saved_break then
				self:PopContextValue("saved_break_state")

				if saved_break ~= nil then push_break_state(self, saved_break) end
			end
		end
	end

	function META:AnalyzeStatementsAndCollectOutputSignatures(statement)
		local scope = self:GetScope()
		scope:MakeFunctionScope(statement)
		self:AnalyzeStatements(statement.statements)

		if scope.missing_return and self:IsMaybeReachable() then
			self:Return(statement, {Nil()})
		end

		local out = {}

		for i, ret in ipairs(scope:GetOutputSignature()) do
			out[i] = ret
		end

		scope:ClearCertainOutputSignatures()
		return out
	end

	function META:ThrowSilentError(assert_expression)
		if assert_expression and assert_expression:IsCertainlyTrue() then return end

		for _, frame in ipairs(self:GetCallStack()) do
			local function_scope = frame.scope:GetNearestFunctionScope()

			if not assert_expression or assert_expression:IsCertainlyTrue() then
				if not self.LEFT_SIDE_OR or self.LEFT_SIDE_OR:IsCertainlyTrue() then
					function_scope.lua_silent_error = function_scope.lua_silent_error or {}
					table_insert(function_scope.lua_silent_error, self:GetScope())
					frame.scope:UncertainReturn()
				end
			end

			if assert_expression and assert_expression:IsTruthy() then
				-- track the assertion expression
				local upvalues
				local tracked = self:GetTrackedUpvalues(nil, frame.scope)

				if tracked[1] then
					upvalues = {}

					for _, a in ipairs(tracked) do
						for _, b in ipairs(self:GetTrackedUpvalues()) do
							if a.upvalue == b.upvalue then table_insert(upvalues, a) end
						end
					end
				end

				local tables
				local tracked = self:GetTrackedTables(nil, frame.scope)

				if tracked[1] then
					tables = {}

					for _, a in ipairs(tracked) do
						for _, b in ipairs(self:GetTrackedTables()) do
							if a.obj == b.obj then table_insert(tables, a) end
						end
					end
				end

				self:PushScope(function_scope)
				self:ApplyMutationsAfterStatement(frame.scope, false, upvalues, tables)
				self:PopScope()
				return
			end

			self:PushScope(function_scope)
			self:ApplyMutationsAfterStatement(
				frame.scope,
				true,
				frame.scope:GetTrackedUpvalues(),
				frame.scope:GetTrackedTables()
			)
			self:PopScope()
		end
	end

	function META:AssertError(obj, msg, level, no_report)
		-- track "if x then" which has no binary or prefix operators
		if obj.Type == "union" then
			self:TrackUpvalueUnion(obj, obj:GetTruthy(), obj:GetFalsy())
		end

		self.lua_assert_error_thrown = {
			msg = msg,
			obj = obj,
		}

		if obj:IsTruthy() then
			self:GetScope():UncertainReturn()
		else
			self:GetScope():CertainReturn()
		end

		local old = {}

		for i, upvalue in ipairs(self:GetScope().upvalues.runtime.list) do
			old[i] = upvalue
		end

		local scope = self:GetScope()
		local u, t = self:GetTrackedUpvalues(old), self:GetTrackedTables()
		self:PushScope(self:GetScope():GetNearestFunctionScope())
		self:ApplyMutationsAfterStatement(scope, false, u, t)
		self:PopScope()

		if not no_report then
			self:PushCurrentExpression(self:GetCallFrame(level).call_node)
			self:Error(msg)
			self:PopCurrentExpression()
		end
	end

	function META:ThrowError(msg, level)
		self.lua_error_thrown = msg
		self:PushCurrentExpression((self:GetCallFrame(level) or self:GetCallFrame(1)).call_node)
		self:Error(error_messages.plain_error(msg))
		self:PopCurrentExpression()
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
			local errored_scope = function_scope.lua_silent_error[1]

			if
				errored_scope and
				self:GetScope():IsCertainFromScope(errored_scope) and
				errored_scope:IsCertain()
			then
				thrown = true
			end
		end

		if not thrown then
			scope:CollectOutputSignatures(node, types)
		else
			scope.throws = true
		end

		if scope:IsUncertain() then
			function_scope:UncertainReturn()
			scope:UncertainReturn()
		else
			function_scope:CertainReturn(self)
			scope:CertainReturn(self)
		end

		self:PushScope(function_scope)
		self:ApplyMutationsAfterStatement(scope, true, scope:GetTrackedUpvalues(), scope:GetTrackedTables())
		self:PopScope()
	end

	do
		local push, get, get_offset, pop, get_stack = META:SetupContextValue("call_stack")

		function META:GetCallStack()
			return get_stack(self) or {}
		end

		function META:GetCallFrame(level)
			return get_offset(self, level or 1)
		end

		function META:PushCallFrame(obj, call_node, not_recursive_call)
			if self.recursively_called[obj] then return self.recursively_called[obj] end

			if
				self:IsRuntime() and
				call_node and
				not not_recursive_call and
				not obj:HasReferenceTypes()
			then
				-- if the callnode is the same, we're doing some infinite recursion
				if self.call_stack_map[call_node] then
					if obj:IsExplicitOutputSignature() then
						-- so if we have explicit return types, just return those
						self.recursively_called[obj] = obj:GetOutputSignature():Copy()
						return self.recursively_called[obj]
					else
						-- if not we sadly have to resort to any
						-- TODO: error?
						self.recursively_called[obj] = Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math_huge))
						return self.recursively_called[obj]
					end
				end
			end

			if #self:GetCallStack() > 100 then
				local len = 501

				while debug_getinfo(len, "") do
					len = len + 1
				end

				self:Error(error_messages.analyzer_callstack_too_deep(#self:GetCallStack(), len))
				return Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
			end

			local val = {
				obj = obj,
				call_node = call_node,
				scope = self:GetScope(),
			}

			if call_node then self.call_stack_map[call_node] = val end

			push(self, val)
		end

		function META:PopCallFrame()
			local val = self:GetCallFrame()
			pop(self)

			if val.call_node then self.call_stack_map[val.call_node] = nil end
		end
	end

	function META:IsDefinetlyReachable()
		do
			local obj = self.LEFT_SIDE_OR

			if obj then
				if obj:IsUncertain() then return false, "left side or is uncertain" end
			end
		end

		local scope = self:GetScope()
		local function_scope = scope:GetNearestFunctionScope()

		if not scope:IsCertain() then return false, "scope is uncertain" end

		if function_scope.uncertain_function_return == true then
			return false, "uncertain function return"
		end

		if function_scope.lua_silent_error then
			for _, scope in ipairs(function_scope.lua_silent_error) do
				if not scope:IsCertain() then
					return false, "parent function scope can throw an error"
				end
			end
		end

		for _, frame in ipairs(self:GetCallStack()) do
			local scope = frame.scope

			if not scope:IsCertain() then
				return false, "call stack scope is uncertain"
			end

			if scope.uncertain_function_return == true then
				return false, "call stack scope has uncertain function return"
			end
		end

		return true
	end

	function META:IsMaybeReachable()
		local scope = self:GetScope()
		local function_scope = scope:GetNearestFunctionScope()

		if function_scope.lua_silent_error then
			for _, scope in ipairs(function_scope.lua_silent_error) do
				if not scope:IsCertain() then return false end
			end
		end

		for _, frame in ipairs(self:GetCallStack()) do
			local parent_scope = frame.scope

			if parent_scope.uncertain_function_return then return true end

			if not parent_scope:IsCertain() and parent_scope:IsCertainFromScope(scope) then
				return false
			end
		end

		return true
	end

	function META:Print(...)
		local node = self:GetCurrentExpression()
		local start, stop = node:GetStartStop()

		do
			local node = self:GetCurrentStatement()
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

		print(node.Code:BuildSourceCodePointMessage(table.concat(str, ", "), start, stop, 1))
	end

	function META:PushConditionalScope(statement, truthy, falsy)
		local scope = self:CreateAndPushScope()
		scope:SetConditionalScope(true)
		scope:SetStatement(statement)
		scope:SetTruthy(truthy)
		scope:SetFalsy(falsy)
		return scope
	end

	function META:PopConditionalScope()
		self:PopScope()
	end
end
