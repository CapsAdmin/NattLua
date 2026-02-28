local ipairs = ipairs
local tostring = tostring
local LString = require("nattlua.types.string").LString
local Any = require("nattlua.types.any").Any
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local ConstString = require("nattlua.types.string").ConstString
local error_messages = require("nattlua.error_messages")
local shared = require("nattlua.types.shared")
return {
	NewIndex = function(META--[[#: any]])
		local function newindex_union(analyzer, obj, key, val)
			for _, v in ipairs(obj:GetData()) do
				analyzer:NewIndexOperator(v, key, val)
			end

			return true
		end

		local function newindex_tuple(analyzer, obj, key, val)
			if analyzer:IsRuntime() then
				analyzer:NewIndexOperator(analyzer:GetFirstValue(obj), key, val)
			end

			return obj:Set(key, val)
		end

		local function newindex_table(analyzer, obj, key, val, raw, allow_nil_set)
			if not raw and obj:GetMetaTable() then
				local func = obj:GetMetaTable():Get(ConstString("__newindex"))

				if func then
					if func.Type == "table" then return func:Set(key, val) end

					if func.Type == "function" then
						return analyzer:Call(func, Tuple({obj, key, val}), analyzer:GetCurrentStatement())
					end
				end
			end

			local contract = obj:GetContract()

			if contract then
				if analyzer:IsRuntime() then
					local existing
					local err

					if obj == contract then
						if obj:GetMetaTable() then
							analyzer:MutateTable(obj, key, val)
							return obj:SetExplicit(key, val)
						else
							existing = obj:GetMutatedValue(key, analyzer:GetScope())
						end
					else
						existing, err = contract:Get(key)
					end

					if existing then
						if val.Type == "function" and existing.Type == "function" then
							if val:GetInputIdentifiers() then
								for i, v in ipairs(val:GetInputIdentifiers()) do
									if not existing:GetInputIdentifiers()[i] then
										analyzer:Error(error_messages.too_many_arguments())

										break
									end
								end
							else
								analyzer:Error(error_messages.too_few_arguments())
							end

							val:SetInputSignature(existing:GetInputSignature())
							val:SetOutputSignature(existing:GetOutputSignature())
							val:SetExplicitOutputSignature(true)
							val:SetExplicitInputSignature(true)
							val:SetCalled(false)
						end

						local ok, err = shared.IsSubsetOf(val, existing)

						if ok then
							if obj == contract then
								analyzer:MutateTable(obj, key, val)
								return true
							end
						else
							if existing.Type == "symbol" and existing:IsNil() then
								local contract_keyval = contract:FindKeyValWide(key)

								if contract_keyval then
									local ok, reason = shared.IsSubsetOf(val, contract_keyval.val)

									if not ok then analyzer:Error(reason) end
								else
									analyzer:Error(err)
								end
							else
								analyzer:Error(err)
							end
						end
					elseif err then
						analyzer:Error(err)
					end
				elseif analyzer:IsTypesystem() then
					return obj:GetContract():SetExplicit(key, val)
				end
			end

			if analyzer:IsTypesystem() then
				if val.Type ~= "symbol" or not val:IsNil() then
					return obj:SetExplicit(key, val)
				else
					return obj:Set(key, val)
				end
			end

			analyzer:MutateTable(obj, key, val)

			if not obj:GetContract() then return obj:Set(key, val, allow_nil_set) end

			return true
		end

		function META:NewIndexOperator(obj, key, val, raw, allow_nil_set)
			if obj.Type == "any" then return true end

			local ok, err

			if obj.Type == "union" then
				ok, err = newindex_union(self, obj, key, val)
			elseif obj.Type == "tuple" then
				ok, err = newindex_tuple(self, obj, key, val)
			elseif obj.Type == "table" then
				ok, err = newindex_table(self, obj, key, val, raw, allow_nil_set)
			else
				ok, err = obj:Set(key, val)
			end

			if not ok then self:Error(err) end
		end
	end,
}