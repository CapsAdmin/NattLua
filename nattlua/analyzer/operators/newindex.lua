local ipairs = ipairs
local tostring = tostring
local LString = require("nattlua.types.string").LString
local Any = require("nattlua.types.any").Any
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
return function(META)
	function META:NewIndexOperator(node, obj, key, val, env)
		if obj.Type == "union" then
            -- local x: nil | {foo = true}
            -- log(x.foo) << error because nil cannot be indexed, to continue we have to remove nil from the union
            -- log(x.foo) << no error, because now x has no field nil
            
            local new_union = Union()
			local truthy_union = Union()
			local falsy_union = Union()

			for _, v in ipairs(obj:GetData()) do
				local ok, err = self:NewIndexOperator(node, v, key, val, env)

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
			new_union:SetTruthyUnion(truthy_union)
			new_union:SetFalsyUnion(falsy_union)
			return new_union:SetNode(node):SetTypeSource(new_union):SetTypeSourceLeft(obj)
		end

		if val.Type == "function" and val:GetNode().self_call then
			local arg = val:GetArguments():Get(1)

			if arg and not arg:GetContract() and not arg.Self then
				val.called = true
				val = val:Copy()
				val:GetArguments():Set(1, Union({Any(), obj}))
				self:CallMeLater(val, val:GetArguments(), val:GetNode(), true)
			end
		end

		self:FireEvent("newindex", obj, key, val, env)

		if obj:GetMetaTable() then
			local func = obj:GetMetaTable():Get(LString("__newindex"))

			if func then
				if func.Type == "table" then return func:Set(key, val) end
				if func.Type == "function" then return self:Assert(node, self:Call(func, Tuple({obj, key, val}), key:GetNode())) end
			end
		end

		if
			obj.Type == "table" and
			obj.argument_index and
			(not obj:GetContract() or not obj:GetContract().mutable) and
			not obj.mutable
		then
			if not obj:GetContract() then
				self:Warning(
					node,
					"mutating function argument " .. tostring(obj) .. " #" .. obj.argument_index .. " without a contract"
				)
			else
				self:Error(
					node,
					"mutating function argument " .. tostring(obj) .. " #" .. obj.argument_index .. " with an immutable contract"
				)
			end
		end

		local contract = obj:GetContract()

		if contract then
			if env == "runtime" then
				local existing
				local err

				if obj == contract then
					existing, err = contract:Get(key)

					if existing then
						existing = self:GetMutatedValue(obj, key, existing, env)
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

							val:GetNode().identifiers[i].inferred_type = existing:GetArguments():Get(i)
						end

						val:SetArguments(existing:GetArguments())
						val:SetReturnTypes(existing:GetReturnTypes())
						val.explicit_arguments = true
					end

					local ok, err = val:IsSubsetOf(existing)

					if ok then
						if obj == contract then
							self:MutateValue(obj, key, val, env)
							return true
						end
					else
						self:Error(node, err)
					end
				else
					self:Error(node, err)
				end
			elseif env == "typesystem" then
				return obj:GetContract():SetExplicit(key, val)
			end
		end

		if env == "typesystem" then
			if obj.Type == "table" then
				return obj:SetExplicit(key, val)
			else
				return obj:Set(key, val)
			end
		end

		self:MutateValue(obj, key, val, env)
		if env == "typesystem" and obj:GetContract() then return obj:GetContract():Set(key, val) end
		return obj:Set(key, val)
	end
end
