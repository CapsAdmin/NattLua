-- Enhanced repeat loop implementation using context management
local error_messages = require("nattlua.error_messages")
return {
	AnalyzeRepeat = function(self, statement)
		-- Analyze the until condition first to understand what we're dealing with
		local condition_obj = self:AnalyzeConditionalExpression(statement.expression)
		-- Enter loop context using enhanced context management
		local loop_scope = self:PushLoopContext(statement, condition_obj)
		local max_iterations = self.max_loop_iterations or 32
		local count = 0
		-- Track upvalues and tables for mutation analysis
		local tracked_objects = self:GetTrackedObjects()
		self:ClearTracked()
		self:ApplyMutationsInIf(tracked_objects)

		-- Execute the repeat loop
		for i = 1, max_iterations do
			count = count + 1
			-- Analyze the statements in the loop body
			self:AnalyzeStatements(statement.statements)

			-- Handle continue statements
			if self._continue_ then self._continue_ = nil end

			-- Use enhanced break checking
			local should_continue, break_reason = self:ShouldContinueLoop(loop_scope)

			if not should_continue then
				if break_reason == "certain_break" then
					self:ClearBreak()

					if self:IsRuntime() and count == 1 then
						-- Warn about potentially useless loop
						self:PushCurrentExpression(statement.expression)
						self:ConstantIfExpressionWarning(error_messages.useless_repeat_loop())
						self:PopCurrentExpression()
					end

					break
				elseif break_reason == "uncertain_break" then
					-- Mark uncertainty for widening in subsequent code
					self:PushBreakUncertainty(loop_scope, true)
					self:ClearBreak()

					if self:IsRuntime() then
						self:PushCurrentExpression(statement.expression)
						self:ConstantIfExpressionWarning("uncertain break in repeat loop")
						self:PopCurrentExpression()
					end

					break
				elseif break_reason == "certain_return" then
					if self:IsRuntime() and count == 1 then
						self:PushCurrentExpression(statement.expression)
						self:ConstantIfExpressionWarning(error_messages.useless_repeat_loop())
						self:PopCurrentExpression()
					end

					break
				end
			end

			-- Re-analyze the condition after each iteration
			local new_condition = self:AnalyzeConditionalExpression(statement.expression)

			-- If condition is certainly true, we can exit
			if new_condition:IsCertainlyTrue() then break end

			-- If condition is certainly false, continue the loop
			if new_condition:IsCertainlyFalse() then
				-- Check for infinite loop
				if i == max_iterations and self:IsRuntime() then
					self:Error(error_messages.too_many_iterations())
				end
			-- Continue to next iteration
			else
				-- Uncertain condition - we need to be conservative and exit
				-- Mark uncertainty for subsequent analysis
				self:PushBreakUncertainty(loop_scope, true)

				break
			end
		end

		-- Ensure we analyze the until condition one final time for type tracking
		self:PushCurrentExpression(statement.expression)
		local final_condition = self:AnalyzeConditionalExpression(statement.expression)
		self:PopCurrentExpression()

		-- Handle runtime warnings for condition analysis
		if self:IsRuntime() then
			if final_condition:IsCertainlyFalse() then
				self:PushCurrentExpression(statement.expression)
				self:ConstantIfExpressionWarning(error_messages.loop_always_false())
				self:PopCurrentExpression()
			elseif final_condition:IsCertainlyTrue() and count <= 1 then
				self:PushCurrentExpression(statement.expression)
				self:ConstantIfExpressionWarning(error_messages.loop_always_true())
				self:PopCurrentExpression()
			end
		end

		-- Clean up the loop context
		self:PopLoopContext(loop_scope)
		-- Apply final mutations
		self:ClearTracked()
	end,
}
