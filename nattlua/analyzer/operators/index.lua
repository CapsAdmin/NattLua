local LString = require("nattlua.types.string").LString
local Nil = require("nattlua.types.symbol").Nil
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
return
	{
		Index = function(META)
			function META:IndexOperator(node, obj, key)
				if obj.Type == "union" then
					local union = Union({})

					for _, obj in ipairs(obj.Data) do
						if obj.Type == "tuple" and obj:GetLength() == 1 then
							obj = obj:Get(1)
						end
												
						-- if we have a union with an empty table, don't do anything
						-- ie {[number] = string} | {}
						if obj.Type == "table" and obj:IsEmpty() then
							
						else
							local val, err = obj:Get(key)

							if not val then
								return val, err
							end

							union:AddType(val)
						end
					end

					union:SetNode(node)

					return union
				end

				if obj.Type ~= "table" and obj.Type ~= "tuple" and (obj.Type ~= "string") then return obj:Get(key) end

				if obj:GetMetaTable() and (obj.Type ~= "table" or not obj:Contains(key)) then
					local index = obj:GetMetaTable():Get(LString("__index"))

					if index then
						if index == obj then return obj:Get(key) end

						if
							index.Type == "table" and
							(
								(index:GetContract() or index):Contains(key) or
								(index:GetMetaTable() and index:GetMetaTable():Contains(LString("__index")))
							)
						then
							return self:IndexOperator(node, index:GetContract() or index, key)
						end

						if index.Type == "function" then
							local obj, err = self:Call(index, Tuple({obj, key}), key:GetNode())
							if not obj then return obj, err end
							return obj:Get(1)
						end
					end
				end

				if obj:GetContract() then
					local val, err = obj:GetContract():Get(key)

					if val and not val:GetContract() then
						val:SetContract(val)
					end

					if val then
						if not obj.argument_index or obj:GetContract().literal_argument then
							local o = self:GetMutatedValue(obj, key, val)
							if o then return o end
						end
					end

					return val, err
				end

				if self:IsTypesystem() then
					return obj:Get(key)
				end

				return self:GetMutatedValue(obj, key, obj:Get(key)) or Nil()
			end
		end,
	}
