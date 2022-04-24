local ipairs = ipairs
local tostring = tostring
local LString = require("nattlua.types.string").LString
local Any = require("nattlua.types.any").Any
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
return {
	NewIndex = function(META)
		function META:NewIndexOperator(node, obj, key, val)
			if obj.Type == "union" then
				-- local x: nil | {foo = true}
				-- log(x.foo) << error because nil cannot be indexed, to continue we have to remove nil from the union
				-- log(x.foo) << no error, because now x has no field nil
				local new_union = Union()
				local truthy_union = Union()
				local falsy_union = Union()

				for _, v in ipairs(obj:GetData()) do
					local ok, err = self:NewIndexOperator(node, v, key, val)

					if not ok then
						self:ErrorAndCloneCurrentScope(node, err or "invalid set error", obj)
						falsy_union:AddType(v)
					else
						truthy_union:AddType(v)
						new_union:AddType(v)
					end
				end

				truthy_union:SetUpvalue(obj:GetUpvalue())
				falsy_union:SetUpvalue(obj:GetUpvalue())
				return new_union:SetNode(node)
			end

			if val.Type == "function" and val:GetNode().self_call then
				local arg = val:GetArguments():Get(1)

				if arg and not arg:GetContract() and not arg.Self then
					val:SetCallOverride(true)
					val = val:Copy()
					val:SetCallOverride(nil)
					val:GetArguments():Set(1, Union({Any(), obj}))
					self:AddToUnreachableCodeAnalysis(val, val:GetArguments(), val:GetNode(), true)
				end
			end

			if obj:GetMetaTable() then
				local func = obj:GetMetaTable():Get(LString("__newindex"))

				if func then
					if func.Type == "table" then return func:Set(key, val) end

					if func.Type == "function" then
						return self:Assert(node, self:Call(func, Tuple({obj, key, val}), key:GetNode()))
					end
				end
			end

			if
				obj.Type == "table" and
				obj.argument_index and
				(
					not obj:GetContract() or
					not obj:GetContract().mutable
				)
				and
				not obj.mutable
			then
				if not obj:GetContract() then
					self:Warning(
						node,
						{
							"mutating function argument ",
							obj,
							" #",
							obj.argument_index,
							" without a contract",
						}
					)
				else
					self:Error(
						node,
						{
							"mutating function argument ",
							obj,
							" #",
							obj.argument_index,
							" with an immutable contract",
						}
					)
				end
			end

			local contract = obj:GetContract()

			if contract then
				if self:IsRuntime() then
					local existing
					local err

					if obj == contract then
						if obj.mutable and obj:GetMetaTable() and obj:GetMetaTable().Self == obj then
							return obj:SetExplicit(key, val)
						else
							existing, err = contract:Get(key)

							if existing then
								existing = self:GetMutatedTableValue(obj, key, existing)
							end
						end
					else
						existing, err = contract:Get(key)
					end

					if existing then
						if val.Type == "function" and existing.Type == "function" then
							for i, v in ipairs(val:GetNode().identifiers) do
								if not existing:GetNode().identifiers[i] then
									self:Error(v, "too many arguments")

									break
								end
							end

							val:SetArguments(existing:GetArguments())
							val:SetReturnTypes(existing:GetReturnTypes())
							val.explicit_arguments = true
						end

						local ok, err = val:IsSubsetOf(existing)

						if ok then
							if obj == contract then
								self:MutateTable(obj, key, val)
								return true
							end
						else
							self:Error(node, err)
						end
					elseif err then
						self:Error(node, err)
					end
				elseif self:IsTypesystem() then
					return obj:GetContract():SetExplicit(key, val)
				end
			end

			if self:IsTypesystem() then
				if obj.Type == "table" and (val.Type ~= "symbol" or val.Data ~= nil) then
					return obj:SetExplicit(key, val)
				else
					return obj:Set(key, val)
				end
			end

			self:MutateTable(obj, key, val)

			if not obj:GetContract() then return obj:Set(key, val, self:IsRuntime()) end

			return true
		end
	end,
}
