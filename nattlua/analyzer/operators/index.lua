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


				if self:IsRuntime() then
					if obj.Type == "tuple" and obj:GetLength() == 1 then
						obj = obj:Get(1)
					end
				end

				if self:IsTypesystem() then
					return obj:Get(key)
				end

				if obj.exp_stack then
					if self:IsTruthyExpressionContext() then
						return obj.exp_stack[#obj.exp_stack].truthy
					elseif self:IsFalsyExpressionContext() then
						return obj.exp_stack[#obj.exp_stack].falsy
					end
				end

				local contract = obj:GetContract()
				if contract then
					local val, err = contract:Get(key)
					if not val then return val, err end

					if not obj.argument_index or contract.ref_argument then
						local o = self:GetMutatedValue(obj, key, val)
						if o then
							if not o:GetContract() then
								o:SetContract(o)
							end

							return o
						end
					end

					return val, err
				end

				local val = self:GetMutatedValue(obj, key, obj:Get(key))

				if val and val.Type == "union" then
					if self:IsTruthyExpressionContext() or self:IsFalsyExpressionContext() then
						local hash = key:GetHash()
						
						if hash then
							obj.exp_stack_map = obj.exp_stack_map or {}
							obj.exp_stack_map[hash] = obj.exp_stack_map[hash] or {}
							table.insert(obj.exp_stack_map[hash], {key = key, truthy = val:GetTruthy(), falsy = val:GetFalsy()})
		
							self.affected_upvalues = self.affected_upvalues or {}
							table.insert(self.affected_upvalues, obj)
						end
					end
				end

				return val or Nil()
			end
		end,
	}
