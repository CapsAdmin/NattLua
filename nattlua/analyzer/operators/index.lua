local types = require("nattlua.types.types")
return function(META)
	function META:IndexOperator(node, obj, key, env)
		if obj.Type == "union" then
			local copy = types.Union()

			for _, v in ipairs(obj:GetData()) do
				local val, err = self:IndexOperator(node, v, key, env)
				if not val then return val, err end
				copy:AddType(val)
			end

			return copy
		end

		if
			obj.Type ~= "table" and
			obj.Type ~= "tuple" and
			obj.Type ~= "list" and
			(obj.Type ~= "string")
		then
			return obj:Get(key)
		end

		if obj:GetMetaTable() and (obj.Type ~= "table" or not obj:Contains(key)) then
			local index = obj:GetMetaTable():Get("__index")

			if index then
				if index.Type == "table" then return self:IndexOperator(node, index:GetContract() or index, key, env) end

				if index.Type == "function" then
					local obj, err = self:Call(index, types.Tuple({obj, key}), key:GetNode())
					if not obj then return obj, err end
					return obj:Get(1)
				end
			end
		end

		if obj:GetContract() then
			local val, err = obj:GetContract():Get(key)

			if val then
				if not obj.argument_index or obj:GetContract().literal_argument then
					local o = self:GetMutatedValue(obj, key, val, env)
					if o then return o end
				end

				local o = self:GetMutatedValue(obj:GetContract(), key, val, env)
				if o then return o end
				return val
			end

			return val, err
		end

		local val, err = obj:Get(key)

		if val then
			local o = self:GetMutatedValue(obj, key, val, env)
			if o then return o end
			return val
		end

		return types.Nil() -- no contract means nil value
    end
end
