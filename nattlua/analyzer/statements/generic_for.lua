local table = require("table")
local ipairs = ipairs
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
return {
		AnalyzeGenericFor = function(self, statement)
			local args = self:AnalyzeExpressions(statement.expressions)
			local callable_iterator = table.remove(args, 1)
			if not callable_iterator then return end

			if callable_iterator.Type == "tuple" then
				callable_iterator = callable_iterator:Get(1)
			end

			local returned_key = nil
			local one_loop = callable_iterator and callable_iterator.Type == "any"
			local uncertain_break = nil

			for i = 1, 1000 do
				local values = self:Assert(statement.expressions[1], self:Call(callable_iterator, Tuple(args), statement.expressions[1]))

				if
					not values:Get(1) or
					values:Get(1).Type == "symbol" and
					values:Get(1):GetData() == nil
				then
					break
				end

					if i == 1 then
						returned_key = values:Get(1)

						if not returned_key:IsLiteral() then
							returned_key = Union({Nil(), returned_key})
						end

						self:PushConditionalScope(statement, returned_key:IsTruthy(), returned_key:IsFalsy())
						self:PushUncertainLoop(false)
					end

					local brk = false

					for i, identifier in ipairs(statement.identifiers) do
						local obj = self:Assert(identifier, values:Get(i))

						if uncertain_break then
							obj:SetLiteral(false)
							brk = true
						end

                        obj.from_for_loop = true
						self:CreateLocalValue(identifier.value.value, obj)
					end

					self:AnalyzeStatements(statement.statements)

					if self._continue_ then
						self._continue_ = nil
					end

					if self.break_out_scope then
						if self.break_out_scope:IsUncertain() then
							uncertain_break = true
						else
							brk = true
						end

						self.break_out_scope = nil
					end

					if i == 1000 then
						self:Error(statement, "too many iterations")
					end

					table.insert(values:GetData(), 1, args[1])
					args = values:GetData()
					if one_loop then break end
					if brk then break end
				end

				if returned_key then
					self:PopConditionalScope()
					self:PopUncertainLoop()
				end
			end,
		}
