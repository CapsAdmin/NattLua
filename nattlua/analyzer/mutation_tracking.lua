local ipairs = ipairs
local table = _G.table
local Union = require("nattlua.types.union").Union
local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.number").LNumberRange
local shallow_copy = require("nattlua.other.shallow_copy")
return function(META)
	function META:GetArrayLengthFromTable(tbl)
		local contract = tbl:GetContract()

		if contract and contract ~= tbl then tbl = contract end

		local len = 0

		for _, kv in ipairs(tbl:GetData()) do
			if tbl:HasMutations() then
				local val = self:GetMutatedTableValue(tbl, kv.key)

				if val then
					if val.Type == "union" and val:CanBeNil() then
						return LNumberRange(len, len + 1)
					end

					if val.Type == "symbol" and val:GetData() == nil then
						return LNumber(len)
					end
				end
			end

			if kv.key.Type == "number" then
				if kv.key:IsLiteral() then
					-- TODO: not very accurate
					if kv.key:GetMax() then return kv.key:Copy() end

					if len + 1 == kv.key:GetData() then
						len = kv.key:GetData()
					else
						break
					end
				else
					return kv.key
				end
			end
		end

		return LNumber(len)
	end

	function META:GetMutatedTableValue(tbl, key)
		return tbl:GetMutatedValue(key, self:GetScope())
	end

	function META:MutateTable(tbl, key, val, from_tracking)
		local scope = self:GetScope()

		if self:IsInUncertainLoop(scope) and tbl:GetCreationScope() then
			if val.dont_widen or scope:Contains(tbl:GetCreationScope()) then
				val = val:Copy()
			else
				val = val:Widen()
			end
		end

		tbl:Mutate(key, val, scope, from_tracking)
	end

	function META:GetMutatedUpvalue(upvalue)
		return upvalue:GetMutatedValue(self:GetScope())
	end

	function META:MutateUpvalue(upvalue, val, from_tracking)
		local scope = self:GetScope()

		if self:IsInUncertainLoop(scope) and upvalue:GetScope() then
			if val.dont_widen or scope:Contains(upvalue:GetScope()) then
				val = val:Copy()
			else
				val = val:Widen()
			end
		end

		upvalue:Mutate(val, scope, from_tracking)
	end

	function META:ClearScopedTrackedObjects(scope)
		if scope.TrackedObjects then
			for _, obj in ipairs(scope.TrackedObjects) do
				if obj.Type == "upvalue" then
					obj:ClearTrackedMutations()
				elseif obj.mutations then
					for _, mutations in pairs(obj.mutations) do
						for i = #mutations, 1, -1 do
							local mut = mutations[i]

							if mut.from_tracking then table.remove(mutations, i) end
						end
					end
				end
			end
		end
	end

	do
		do
			function META:PushTruthyExpressionContext(b)
				self:PushContextValue("truthy_expression_context", b)
			end

			function META:PopTruthyExpressionContext()
				self:PopContextValue("truthy_expression_context")
			end

			function META:IsTruthyExpressionContext()
				return self:GetContextValue("truthy_expression_context") == true
			end
		end

		do
			function META:PushFalsyExpressionContext(b)
				self:PushContextValue("falsy_expression_context", b)
			end

			function META:PopFalsyExpressionContext()
				self:PopContextValue("falsy_expression_context")
			end

			function META:IsFalsyExpressionContext()
				return self:GetContextValue("falsy_expression_context") == true
			end
		end

		do
			function META:TrackUpvalue(obj)
				local upvalue = obj:GetUpvalue()

				if not upvalue then return end

				self.tracked_upvalues = self.tracked_upvalues or {}
				self.tracked_upvalues_done = self.tracked_upvalues_done or {}

				if not self.tracked_upvalues_done[upvalue] then
					table.insert(self.tracked_upvalues, upvalue)
					self.tracked_upvalues_done[upvalue] = true
				end
			end

			function META:TrackDependentUpvalues(obj)
				local upvalue = obj:GetUpvalue()

				if not upvalue then return end

				local val = upvalue:GetValue()

				if val.truthy_union and val.truthy_union:GetUpvalue() then
					self:TrackUpvalueUnion(val.truthy_union:GetUpvalue():GetValue(), val.truthy_union, val.falsy_union)
				end

				if val.right_source then self:TrackDependentUpvalues(val.right_source) end

				if val.left_source then self:TrackDependentUpvalues(val.left_source) end
			end

			function META:TrackUpvalueUnion(obj, truthy_union, falsy_union, inverted)
				local upvalue = obj:GetUpvalue()

				if not upvalue then return end

				upvalue.tracked_stack = upvalue.tracked_stack or {}
				table.insert(
					upvalue.tracked_stack,
					{
						truthy = truthy_union,
						falsy = falsy_union,
						inverted = inverted,
					}
				)
				self:TrackUpvalue(obj)
			end

			function META:GetTrackedUpvalue(obj)
				local upvalue = obj:GetUpvalue()
				local stack = upvalue and upvalue.tracked_stack

				if not stack then return end

				if self:IsTruthyExpressionContext() then
					return stack[#stack].truthy:SetUpvalue(upvalue)
				elseif self:IsFalsyExpressionContext() then
					local union = stack[#stack].falsy

					if union:GetCardinality() == 0 then
						union = Union()

						for _, val in ipairs(stack) do
							union:AddType(val.falsy)
						end
					end

					union:SetUpvalue(upvalue)
					return union
				end
			end

			function META:GetTrackedUpvalues(old_upvalues)
				local upvalues = {}
				local translate = {}

				if old_upvalues then
					for i, upvalue in ipairs(self:GetScope().upvalues.runtime.list) do
						local old = old_upvalues[i]
						translate[old] = upvalue
						upvalue.tracked_stack = old.tracked_stack
					end
				end

				if self.tracked_upvalues then
					for _, upvalue in ipairs(self.tracked_upvalues) do
						local stack = upvalue.tracked_stack

						if old_upvalues then upvalue = translate[upvalue] end

						table.insert(upvalues, {upvalue = upvalue, stack = stack and shallow_copy(stack)})
					end
				end

				return upvalues
			end

			function META:ClearTrackedUpvalues()
				if self.tracked_upvalues then
					for _, upvalue in ipairs(self.tracked_upvalues) do
						upvalue.tracked_stack = nil
					end

					self.tracked_upvalues_done = nil
					self.tracked_upvalues = nil
				end
			end
		end

		do
			function META:TrackTableIndex(tbl, key, val)
				val.parent_table = tbl
				val.parent_key = key
				local truthy_union = val:GetTruthy()
				local falsy_union = val:GetFalsy()
				self:TrackTableIndexUnion(tbl, key, truthy_union, falsy_union, self.inverted_index_tracking, true)
			end

			function META:TrackTableIndexUnion(tbl, key, truthy_union, falsy_union, inverted, truthy_falsy)
				local hash = key:GetHash()

				if hash == nil then return end

				tbl.tracked_stack = tbl.tracked_stack or {}
				tbl.tracked_stack[hash] = tbl.tracked_stack[hash] or {}

				if falsy_union then
					falsy_union.parent_table = tbl
					falsy_union.parent_key = key
				end

				if truthy_union then
					truthy_union.parent_table = tbl
					truthy_union.parent_key = key
				end

				for i = #tbl.tracked_stack[hash], 1, -1 do
					local tracked = tbl.tracked_stack[hash][i]

					if tracked.truthy_falsy then
						table.remove(tbl.tracked_stack[hash], i)
					end
				end

				table.insert(
					tbl.tracked_stack[hash],
					{
						contract = tbl:GetContract(),
						key = key,
						truthy = truthy_union,
						falsy = falsy_union,
						inverted = inverted,
						truthy_falsy = truthy_falsy,
					}
				)
				self.tracked_tables = self.tracked_tables or {}
				self.tracked_tables_done = self.tracked_tables_done or {}

				if not self.tracked_tables_done[tbl] then
					table.insert(self.tracked_tables, tbl)
					self.tracked_tables_done[tbl] = true
				end
			end

			function META:GetTrackedTableWithKey(tbl, key)
				if not tbl.tracked_stack then return end

				local hash = key:GetHash()

				if hash == nil then return end

				local stack = tbl.tracked_stack[hash]

				if not stack then return end

				if self:IsTruthyExpressionContext() then
					return stack[#stack].truthy
				elseif self:IsFalsyExpressionContext() then
					return stack[#stack].falsy
				end
			end

			function META:GetTrackedTables()
				local tables = {}

				if self.tracked_tables then
					for _, tbl in ipairs(self.tracked_tables) do
						if tbl.tracked_stack then
							for _, stack in pairs(tbl.tracked_stack) do
								table.insert(
									tables,
									{
										obj = tbl,
										key = stack[#stack].key,
										stack = shallow_copy(stack),
									}
								)
							end
						end
					end
				end

				return tables
			end

			function META:ClearTrackedTables()
				if self.tracked_tables then
					for _, tbl in ipairs(self.tracked_tables) do
						tbl.tracked_stack = nil
					end

					self.tracked_tables_done = nil
					self.tracked_tables = nil
				end
			end
		end

		function META:ClearTracked()
			self:ClearTrackedUpvalues()
			self:ClearTrackedTables()
		end

		--[[
			local x: 1 | 2 | 3

			if x == 1 then
				assert(x == 1)
			end
		]] function META:ApplyMutationsInIf(upvalues, tables)
			if upvalues then
				for _, data in ipairs(upvalues) do
					if data.stack then
						local union = Union()

						for _, v in ipairs(data.stack) do
							if v.truthy then union:AddType(v.truthy) end
						end

						if not union:IsEmpty() then
							union:SetUpvalue(data.upvalue)
							self:MutateUpvalue(data.upvalue, union, true)
						end
					end
				end
			end

			if tables then
				for _, data in ipairs(tables) do
					local union = Union()

					for _, v in ipairs(data.stack) do
						if v.truthy then union:AddType(v.truthy) end
					end

					if not union:IsEmpty() then
						self:MutateTable(data.obj, data.key, union, true)
					end
				end
			end
		end

		--[[
			local x: 1 | 2 | 3

			if x == 1 then
			else
				-- we get the original value and remove the truthy values (x == 1) and end up with 2 | 3
				assert(x == 2 | 3)
			end
		]] function META:ApplyMutationsInIfElse(blocks)
			for i, block in ipairs(blocks) do
				if block.upvalues then
					for _, data in ipairs(block.upvalues) do
						if data.stack then
							local union = self:GetMutatedUpvalue(data.upvalue)

							if union.Type == "union" then
								for _, v in ipairs(data.stack) do
									union:RemoveType(v.truthy)
								end

								union:SetUpvalue(data.upvalue)
							end

							self:MutateUpvalue(data.upvalue, union, true)
						end
					end
				end

				if block.tables then
					for _, data in ipairs(block.tables) do
						local union = self:GetMutatedTableValue(data.obj, data.key)

						if union then
							if union.Type == "union" then
								for _, v in ipairs(data.stack) do
									union:RemoveType(v.truthy)
								end
							end

							self:MutateTable(data.obj, data.key, union, true)
						end
					end
				end
			end
		end

		--[[
			local x: 1 | 2 | 3

			if x == 1 then return end

			assert(x == 2 | 3)
		]] --[[
			local x: 1 | 2 | 3

			if x == 1 then else return end

			assert(x == 1)
		]] --[[
			local x: 1 | 2 | 3

			if x == 1 then error("!") end

			assert(x == 2 | 3)
		]] local function solve(data, scope, negate)
			local stack = data.stack

			if stack then
				local val

				if negate and not (scope:IsElseConditionalScope() or stack[#stack].inverted) then
					val = stack[#stack].falsy
				else
					val = stack[#stack].truthy
				end

				if val and (val.Type ~= "union" or not val:IsEmpty()) then
					if val.Type == "union" and #val:GetData() == 1 then
						val = val:GetData()[1]
					end

					return val
				end
			end
		end

		function META:ApplyMutationsAfterReturn(scope, scope_override, negate, upvalues, tables)
			self:PushScope(scope_override)

			if upvalues then
				for _, data in ipairs(upvalues) do
					local val = solve(data, scope, negate)

					if val then
						val:SetUpvalue(data.upvalue)
						self:MutateUpvalue(data.upvalue, val, true)
					end
				end
			end

			if tables then
				for _, data in ipairs(tables) do
					local val = solve(data, scope, negate)

					if val then self:MutateTable(data.obj, data.key, val, true) end
				end
			end

			self:PopScope()
		end
	end
end
