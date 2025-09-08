local ipairs = ipairs
local math = math
local assert = assert
local True = require("nattlua.types.symbol").True
local Number = require("nattlua.types.number").Number
local LNumber = require("nattlua.types.number").LNumber
local False = require("nattlua.types.symbol").False
local Union = require("nattlua.types.union").Union
local BinaryCustom = require("nattlua.analyzer.operators.binary").BinaryCustom
local LNumberRange = require("nattlua.types.range").LNumberRange

local function get_largest_number(obj)
	if not obj:IsLiteral() then return end

	if obj.Type == "union" then
		local max = -math.huge

		for _, v in ipairs(obj:GetData()) do
			if v:IsNumeric() then
				if v.Type == "range" then
					max = math.max(max, v:GetMax())
				else
					max = math.max(max, v:GetData())
				end
			end
		end

		return max
	elseif obj.Type == "range" then
		return obj:GetMax()
	end

	return obj:GetData()
end

return {
	AnalyzeNumericFor = function(self, statement)
		local init = self:GetFirstValue(self:AnalyzeExpression(statement.expressions[1]))
		local max = self:GetFirstValue(self:AnalyzeExpression(statement.expressions[2]))
		local step = statement.expressions[3] and
			self:GetFirstValue(self:AnalyzeExpression(statement.expressions[3]))

		if step then assert(step:IsNumeric()) end

		local literal_init = get_largest_number(init)
		local literal_max = get_largest_number(max)
		local literal_step = not step and 1 or get_largest_number(step)
		local condition = Union()

		if literal_init and literal_max then
			-- also check step
			condition:AddType(BinaryCustom(self, statement, init, max, "<="))
		else
			condition:AddType(True())
			condition:AddType(False())
		end

		local loop_scope = self:PushConditionalScope(statement, condition:IsTruthy(), condition:IsFalsy())
		loop_scope:SetLoopScope(true)

		if literal_init and literal_max and literal_step and literal_max < 1000 then
			for i = literal_init, literal_max, literal_step do
				local brk = false
				-- Use context-based uncertainty checking
				local is_uncertain = self:IsInBreakUncertainty(loop_scope) or
					self:IsInUncertainLoop(loop_scope) or
					self:DidUncertainBreak()

				if is_uncertain then
					self:PushUncertainLoop(loop_scope)
					-- Use enhanced widening with context awareness
					i = self:WidenForUncertainty(LNumber(i), loop_scope)
					brk = true
				else
					i = LNumber(i)
				end

				local upvalue = self:CreateLocalValue(statement.identifiers[1].value.value, i)
				upvalue:SetFromForLoop(true)
				self:AnalyzeStatements(statement.statements)

				if self._continue_ then self._continue_ = nil end

				-- Use enhanced break checking
				local certain_break, uncertain_break = self:DidBreakForLoop(loop_scope)

				if certain_break then
					brk = true
					self:ClearBreak()
				elseif uncertain_break then
					self:PushBreakUncertainty(loop_scope, true)
					self:ClearBreak()
					brk = false
				end

				if is_uncertain then self:PopUncertainLoop() end

				if brk then break end
			end
		else
			-- Non-literal case with enhanced uncertainty
			if literal_init then
				if max:IsNumeric() then
					if not max:IsLiteral() then
						init = LNumberRange(literal_init, math.huge)
					elseif literal_max then
						init = LNumberRange(literal_init, literal_max)
					else
						init = LNumberRange(literal_init, max)
					end
				else
					init = LNumber(literal_init)
				end

				if init.Type == "number" then init:SetDontWiden(true) end
			else
				if init:IsNumeric() and max:IsNumeric() then
					if init:IsLiteral() and max:IsLiteral() then
						init = LNumberRange(init:GetData(), max:GetData())
					end
				end

				if max.Type == "any" then
					init = self:WidenForUncertainty(init, loop_scope)
				end
			end

			self:PushUncertainLoop(loop_scope)
			self:PushBreakUncertainty(loop_scope, true)
			local range = self:Assert(init)
			self:CreateLocalValue(statement.identifiers[1].value.value, range)
			self:AnalyzeStatements(statement.statements)
			self:PopBreakUncertainty()
			self:PopUncertainLoop()
		end

		self:PopConditionalScope()
	end,
}
