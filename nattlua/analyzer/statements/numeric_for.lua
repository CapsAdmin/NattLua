local ipairs = ipairs
local math = math
local assert = assert
local True = require("nattlua.types.symbol").True
local LNumber = require("nattlua.types.number").LNumber
local False = require("nattlua.types.symbol").False
local Union = require("nattlua.types.union").Union
local Binary = require("nattlua.analyzer.operators.binary").Binary

local function get_largest_number(obj)
	if obj:IsLiteral() then
		if obj.Type == "union" then
			local max = -math.huge

			for _, v in ipairs(obj:GetData()) do
				max = math.max(max, v:GetData())
			end

			return max
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

		if step then assert(step.Type == "number") end

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

		self:PushConditionalScope(statement, condition:IsTruthy(), condition:IsFalsy())

		if literal_init and literal_max and literal_step and literal_max < 1000 then
			local uncertain_break = false

			for i = literal_init, literal_max, literal_step do
				self:PushConditionalScope(statement, condition:IsTruthy(), condition:IsFalsy())
				local i = LNumber(i):SetNode(statement.expressions[1])
				local brk = false

				if uncertain_break then
					i:SetLiteral(false)
					brk = true
				end

				i.from_for_loop = true
				self:CreateLocalValue(statement.identifiers[1].value.value, i)
				self:AnalyzeStatements(statement.statements)

				if self._continue_ then self._continue_ = nil end

				if self.break_out_scope then
					if self.break_out_scope:IsUncertain() then
						uncertain_break = true
					else
						brk = true
					end

					self.break_out_scope = nil
				end

				self:PopConditionalScope()

				if brk then break end
			end
		else
			if literal_init then
				init = LNumber(literal_init)
				init.dont_widen = true

				if max.Type == "number" or (max.Type == "union" and max:IsType("number")) then
					if not max:IsLiteral() then
						init:SetMax(LNumber(math.huge))
					else
						init:SetMax(max)
					end
				end
			else
				if
					init.Type == "number" and
					(
						max.Type == "number" or
						(
							max.Type == "union" and
							max:IsType("number")
						)
					)
				then
					init = self:Assert(statement.expressions[1], init:SetMax(max))
				end

				if max.Type == "any" then init:SetLiteral(false) end
			end

			self:PushUncertainLoop(true)
			local range = self:Assert(statement.expressions[1], init)
			self:CreateLocalValue(statement.identifiers[1].value.value, range)
			self:AnalyzeStatements(statement.statements)
			self:PopUncertainLoop()
		end

		self.break_out_scope = nil
		self:PopConditionalScope()
	end,
}
