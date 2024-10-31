local ipairs = ipairs
local tostring = tostring
local LString = require("nattlua.types.string").LString
local Any = require("nattlua.types.any").Any
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local ConstString = require("nattlua.types.string").ConstString
local type_errors = require("nattlua.types.error_messages")
return {
	NewIndex = function(META)
		local function newindex_union(analyzer, obj, key, val)
			for _, v in ipairs(obj:GetData()) do
				analyzer:NewIndexOperator(v, key, val)
			end

			return true
		end

		local function newindex_table(analyzer, obj, key, val, raw)
			if not raw and obj:GetMetaTable() then
				local func = obj:GetMetaTable():Get(ConstString("__newindex"))

				if func then
					if func.Type == "table" then return func:Set(key, val) end

					if func.Type == "function" then
						return analyzer:Call(func, Tuple({obj, key, val}), analyzer.current_statement)
					end
				end
			end

			if
				obj.argument_index and
				(
					not obj:GetContract() or
					not obj:GetContract().mutable
				)
				and
				not obj.mutable
			then
				if not obj:GetContract() then
					analyzer:Warning(type_errors.mutating_function_argument(obj, obj.argument_index))
				else
					analyzer:Error(type_errors.mutating_immutable_function_argument(obj, obj.argument_index))
				end
			end

			local contract = obj:GetContract()

			if contract then
				if analyzer:IsRuntime() then
					local existing
					local err

					if obj == contract then
						if obj.mutable and obj:GetMetaTable() and obj:GetMetaTable().Self == obj then
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
							for i, v in ipairs(val:GetInputIdentifiers()) do
								if not existing:GetInputIdentifiers()[i] then
									analyzer:Error("too many arguments")

									break
								end
							end

							val:SetInputSignature(existing:GetInputSignature())
							val:SetOutputSignature(existing:GetOutputSignature())
							val:SetExplicitOutputSignature(true)
							val:SetExplicitInputSignature(true)
							val:SetCalled(false)
						end

						local ok, err = val:IsSubsetOf(existing)

						if ok then
							if obj == contract then
								analyzer:MutateTable(obj, key, val)
								return true
							end
						else
							analyzer:Error(err)
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

			if not obj:GetContract() then
				return obj:Set(key, val, analyzer:IsRuntime())
			end

			return true
		end

		function META:NewIndexOperator(obj, key, val, raw)
			if
				val.Type == "function" and
				val:GetFunctionBodyNode() and
				val:GetFunctionBodyNode().self_call
			then
				local arg = val:GetInputSignature():GetWithNumber(1)

				if
					arg and
					arg.Type == "table" and
					not arg:GetContract()
					and
					not arg.Self and
					obj.Self2 ~= arg and
					not self:IsTypesystem()
				then
					val:SetCalled(true)
					val = val:Copy()
					val:SetCalled(false)
					val:GetInputSignature():Set(1, Union({Any(), obj}))
					self:AddToUnreachableCodeAnalysis(val, val:GetInputSignature(), val:GetFunctionBodyNode(), true)
				end
			end

			if obj.Type == "union" then
				return self:Assert(newindex_union(self, obj, key, val))
			elseif obj.Type == "table" then
				return self:Assert(newindex_table(self, obj, key, val, raw))
			elseif obj.Type == "any" then
				return true
			end

			return self:Assert(obj:Set(key, val))
		end
	end,
}
