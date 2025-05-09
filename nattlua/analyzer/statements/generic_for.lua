local table = _G.table
local ipairs = ipairs
local Tuple = require("nattlua.types.tuple").Tuple
local NormalizeTuples = require("nattlua.types.tuple").NormalizeTuples
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local type_errors = require("nattlua.types.error_messages")
return {
	AnalyzeGenericFor = function(self, statement)
		local args = self:AnalyzeExpressions(statement.expressions)
		local callable_iterator = table.remove(args, 1)

		if not callable_iterator then return end

		if callable_iterator.Type == "tuple" then
			callable_iterator = callable_iterator:GetWithNumber(1)

			if not callable_iterator then return end
		end

		local returned_key = nil
		local one_loop = callable_iterator and
			callable_iterator.Type == "any" or
			args[1] and
			args[1].Type == "any"
		local uncertain_break = nil

		for i = 1, 1000 do
			local values = self:Assert(self:Call(callable_iterator, Tuple(args), statement.expressions[1]))

			if values.Type == "tuple" and values:HasOneValue() then
				values = values:GetWithNumber(1)
			end

			if values.Type == "union" then
				local tup = Tuple()
				local max_length = 0

				for i, v in ipairs(values:GetData()) do
					if v.Type == "tuple" and v:GetElementCount() > max_length then
						max_length = v:GetElementCount()
					end
				end

				if max_length ~= math.huge then
					for i = 1, max_length do
						tup:Set(i, values:GetAtTupleIndex(i))
					end

					values = tup
				end
			end

			if values.Type ~= "tuple" then values = Tuple({values}) end

			local first_val = values:GetWithNumber(1)

			if not first_val or first_val.Type == "symbol" and first_val:IsNil() then
				break
			end

			if i == 1 then
				returned_key = first_val

				if not returned_key:IsLiteral() then
					returned_key = Union({Nil(), returned_key})
				end

				self:PushConditionalScope(statement, returned_key:IsTruthy(), returned_key:IsFalsy()):SetLoopScope(true)
				self:PushUncertainLoop(false)
			end

			local brk = false

			for i, identifier in ipairs(statement.identifiers) do
				local obj = self:Assert(values:GetWithNumber(i))

				if obj.Type == "union" then obj:RemoveType(Nil()) end

				if uncertain_break then
					obj = obj:Widen()
					brk = true
				end

				local upvalue = self:CreateLocalValue(identifier.value.value, obj)
				upvalue:SetFromForLoop(true)
				identifier:AssociateType(obj)
			end

			self:CreateAndPushScope():SetLoopIteration(i)
			self:AnalyzeStatements(statement.statements)
			self:PopScope()

			if self._continue_ then self._continue_ = nil end

			if self:DidCertainBreak() then
				brk = true
				self:ClearBreak()
			elseif self:DidUncertainBreak() then
				uncertain_break = true
				self:ClearBreak()
			end

			if one_loop then break end

			if brk then break end

			if i == (self.max_iterations or 1000) and self:IsRuntime() then
				self:Error(type_errors.too_many_iterations())
			end
		end

		if returned_key then
			self:PopConditionalScope()
			self:PopUncertainLoop()
		end
	end,
}
