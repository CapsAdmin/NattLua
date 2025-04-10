local ipairs = ipairs
local math = math
local assert = assert
local True = require("nattlua.types.symbol").True
local Number = require("nattlua.types.number").Number
local LNumber = require("nattlua.types.number").LNumber
local False = require("nattlua.types.symbol").False
local Union = require("nattlua.types.union").Union
local Binary = require("nattlua.analyzer.operators.binary").Binary
local LNumberRange = require("nattlua.types.range").LNumberRange

local function get_largest_number(obj)
	if obj:IsLiteral() then
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
end

return {
	AnalyzeNumericFor = function(self, statement)
		local init = self:AnalyzeExpression(statement.expressions[1]):GetFirstValue()
		local max = self:AnalyzeExpression(statement.expressions[2]):GetFirstValue()
		local step = statement.expressions[3] and
			self:AnalyzeExpression(statement.expressions[3]):GetFirstValue() or
			nil

		if step then assert(step:IsNumeric()) end

		local literal_init = get_largest_number(init)
		local literal_max = get_largest_number(max)
		local literal_step = not step and 1 or get_largest_number(step)
		local condition = Union()

		if literal_init and literal_max then
			-- also check step
			condition:AddType(Binary(self, statement, init, max, "<="))
		else
			condition:AddType(True())
			condition:AddType(False())
		end

		local loop_scope = self:PushConditionalScope(statement, condition:IsTruthy(), condition:IsFalsy())
		loop_scope:SetLoopScope(true)

		if literal_init and literal_max and literal_step and literal_max < 1000 then
			for i = literal_init, literal_max, literal_step do
				self:PushConditionalScope(statement, condition:IsTruthy(), condition:IsFalsy())
				local brk = false
				local uncertain_break = self:DidUncertainBreak()

				if uncertain_break then
					self:PushUncertainLoop(loop_scope)
					i = Number()
					brk = true
				else
					i = LNumber(i)
				end

				local upvalue = self:CreateLocalValue(statement.identifiers[1].value.value, i)
				upvalue:SetFromForLoop(true)
				self:AnalyzeStatements(statement.statements)

				if self._continue_ then self._continue_ = nil end

				self:PopConditionalScope()

				if self:DidCertainBreak() then brk = true end

				if uncertain_break then self:PopUncertainLoop() end

				if brk then
					self:ClearBreak()

					break
				end
			end
		else
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

				if max.Type == "any" then init = init:Widen() end
			end

			self:PushUncertainLoop(loop_scope)
			local range = self:Assert(init)
			self:CreateLocalValue(statement.identifiers[1].value.value, range)
			self:AnalyzeStatements(statement.statements)
			self:PopUncertainLoop()
		end

		self:PopConditionalScope()
	end,
}
