local types = require("nattlua.types.types")
return function(META)
	function META:AnalyzeGenericForStatement(statement)
		local args = self:AnalyzeExpressions(statement.expressions)
		local obj = table.remove(args, 1)
		if not obj then return end

		if obj.Type == "tuple" then
			obj = obj:Get(1)
		end

		local returned_key = nil
		local one_loop = obj and obj.Type == "any"
		local uncertain_break = nil

		for i = 1, 1000 do
			local values = self:Assert(statement.expressions[1], self:Call(obj, types.Tuple(args), statement.expressions[1]))

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
					returned_key = types.Union({types.Symbol(nil), returned_key})
				end

				self:CreateAndPushScope()
					self:OnEnterConditionalScope({
						type = "generic_for",
						condition = returned_key,
					})
					self:FireEvent("generic_for", statement.identifiers, values)
				end

				local brk = false

				for i, identifier in ipairs(statement.identifiers) do
					local obj = values:Get(i)

					if uncertain_break then
						obj:SetLiteral(false)
						brk = true
					end

					self:CreateLocalValue(identifier, obj, "runtime")
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
				self:PopScope()
				self:OnExitConditionalScope({condition = returned_key})
			end
		end
	end
