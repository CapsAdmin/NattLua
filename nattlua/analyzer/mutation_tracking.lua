local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.range").LNumberRange
local shallow_copy = require("nattlua.other.tablex").copy
return function(META--[[#: any]])
	META:AddInitializer(function(self)
		self.tracked_upvalues = {}
		self.tracked_upvalues_done = {}
	end)

	function META:GetArrayLengthFromTable(tbl)
		local contract = tbl:GetContract()

		if contract and contract ~= tbl then tbl = contract end

		local len = 0

		for _, kv in ipairs(tbl:GetData()) do
			if tbl:HasMutations() then
				local val = self:GetMutatedTableValue(tbl, kv.key)

				if val then
					if val.Type == "union" and val:IsNil() then
						return LNumberRange(len, len + 1)
					end

					if val.Type == "symbol" and val:IsNil() then return LNumber(len) end
				end
			end

			if kv.key:IsNumeric() then
				if kv.key:IsLiteral() then
					-- TODO: not very accurate
					if kv.key.Type == "range" then return kv.key:Copy() end

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
			if
				(
					val.Type == "number" and
					val:IsDontWiden()
				) or
				scope:Contains(tbl:GetCreationScope())
			then
				val = val:Copy()
			else
				val = val:Widen()
			end
		end

		self:AssertWarning(tbl:Mutate(key, val, scope, from_tracking))
	end

	function META:GetMutatedUpvalue(upvalue)
		return upvalue:GetMutatedValue(self:GetScope())
	end

	function META:MutateUpvalue(upvalue, val, from_tracking)
		local scope = self:GetScope()

		if self:IsInUncertainLoop(scope) and upvalue:GetScope() then
			if (val.Type == "number" and val:IsDontWiden()) or scope:Contains(upvalue:GetScope()) then
				val = val:Copy()
			else
				val = val:Widen()
			end
		end

		self:AssertWarning(upvalue:Mutate(val, scope, from_tracking))
	end

	function META:ClearScopedTrackedObjects(scope)
		if scope.TrackedObjects then
			for _, obj in ipairs(scope.TrackedObjects) do
				if obj.Type == "upvalue" then
					obj:ClearTrackedMutations()
				elseif obj:HasMutations() then
					for _, mutations in ipairs(obj:GetMutationsi()) do
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
			local push, get, pop = META:SetupContextRef("truthy_expression_context")

			function META:PushTruthyExpressionContext()
				push(self)
			end

			function META:PopTruthyExpressionContext()
				pop(self)
			end

			function META:IsTruthyExpressionContext()
				return get(self)
			end
		end

		do
			local push, get, pop = META:SetupContextRef("context_values")

			function META:PushFalsyExpressionContext()
				push(self)
			end

			function META:PopFalsyExpressionContext()
				pop(self)
			end

			function META:IsFalsyExpressionContext()
				return get(self)
			end
		end

		do
			local push, get, pop = META:SetupContextRef("inverted_expression_context")

			function META:PushInvertedExpressionContext()
				push(self)
			end

			function META:PopInvertedExpressionContext()
				pop(self)
			end

			function META:IsInvertedExpressionContext()
				return get(self)
			end
		end

		do
			function META:TrackDependentUpvalues(obj)
				local upvalue = obj:GetUpvalue()

				if not upvalue then return end

				local val = upvalue:GetValue()
				local truthy_falsy = upvalue:GetTruthyFalsyUnion()

				if truthy_falsy then
					self:TrackUpvalueUnion(upvalue:GetValue(), truthy_falsy.truthy, truthy_falsy.falsy)
				end

				if val.Type == "union" then
					local left_right = val:GetLeftRightSource()

					if left_right then
						self:TrackDependentUpvalues(left_right.left)
						self:TrackDependentUpvalues(left_right.right)
					end
				end
			end

			function META:TrackUpvalueUnion(obj, truthy_union, falsy_union, inverted)
				local upvalue = obj:GetUpvalue()

				if not upvalue then return false, "no upvalue" end

				local scope = self:GetScope()

				if not scope then return false, "no scope" end

				local data = self.tracked_upvalues_done[upvalue]

				if not data then
					data = {upvalue = upvalue, stack = {}}
					table.insert(self.tracked_upvalues, data)
					self.tracked_upvalues_done[upvalue] = data
				end

				table.insert(
					data.stack,
					{
						truthy = truthy_union,
						falsy = falsy_union,
						inverted = inverted,
						scope = scope,
					}
				)
				return true
			end

			function META:DumpUpvalueTracking(obj)
				local upvalue = obj:GetUpvalue()

				if not upvalue then return "no upvalue" end

				if not self.tracked_upvalues_done[upvalue] then
					return "no upvalues done"
				end

				local data = self.tracked_upvalues_done[upvalue]

				if not data.stack then return "no stack" end

				local str = tostring(data.upvalue) .. "\n"

				for i, v in ipairs(data.stack) do
					str = str .. "T=" .. tostring(v.truthy:Simplify()) .. " F=" .. tostring(v.falsy:Simplify()) .. "\n"
				end

				print(str)
			end

			function META:GetTrackedUpvalue(obj)
				local upvalue = obj:GetUpvalue()
				local stack = self.tracked_upvalues_done[upvalue] and
					self.tracked_upvalues_done[upvalue].stack

				if not stack then return end

				if self:IsInvertedExpressionContext() then
					if self:IsFalsyExpressionContext() then
						return stack[#stack].falsy:SetUpvalue(upvalue)
					elseif self:IsTruthyExpressionContext() then
						local union = stack[#stack].truthy

						if union.Type == "union" and union:GetCardinality() == 0 then
							union = Union()

							for _, val in ipairs(stack) do
								union:AddType(val.truthy)
							end
						end

						union:SetUpvalue(upvalue)
						return union
					end
				else
					if self:IsTruthyExpressionContext() then
						return stack[#stack].truthy:SetUpvalue(upvalue)
					elseif self:IsFalsyExpressionContext() then
						local union = stack[#stack].falsy

						if union.Type == "union" and union:GetCardinality() == 0 then
							union = Union()

							for _, val in ipairs(stack) do
								union:AddType(val.falsy)
							end
						end

						union:SetUpvalue(upvalue)
						return union
					end
				end
			end

			function META:GetTrackedUpvalues(old_upvalues, scope)
				local upvalues = {}
				local translate = {}
				scope = scope or self:GetScope()

				if old_upvalues then
					for i, upvalue in ipairs(scope.upvalues.runtime.list) do
						local old = old_upvalues[i]
						translate[old] = upvalue
					end
				end

				for _, data in ipairs(self.tracked_upvalues) do
					local stack = data.stack
					local upvalue = data.upvalue

					if old_upvalues then upvalue = translate[upvalue] end

					-- stack is needed to simply track upvalues used, even if they were not mutated for warnings
					if upvalue then
						table.insert(upvalues, {upvalue = upvalue, stack = stack and shallow_copy(stack)})
					end
				end

				return upvalues
			end

			function META:ClearTrackedUpvalues()
				self.tracked_upvalues_done = {}
				self.tracked_upvalues = {}
			end
		end

		do
			function META:TrackTableIndex(tbl, key, val)
				val:SetParentTable(tbl, key)
				local truthy_union = val:GetTruthy()
				local falsy_union = val:GetFalsy()
				self:TrackTableIndexUnion(val, truthy_union, falsy_union, true)
			end

			function META:TrackTableIndexUnion(obj, truthy_union, falsy_union, truthy_falsy)
				local tbl_key = obj:GetParentTable()

				if not tbl_key then return end

				local tbl = tbl_key.table
				local key = tbl_key.key
				local hash = key:GetHashForMutationTracking()

				if hash == nil then return end

				local scope = self:GetScope()

				if not scope then return end

				self.tracked_tables = self.tracked_tables or {}
				self.tracked_tables_done = self.tracked_tables_done or {}
				local data

				if self.tracked_tables_done[tbl] then
					data = self.tracked_tables_done[tbl]
				else
					data = {tbl = tbl}
					table.insert(self.tracked_tables, data)
					self.tracked_tables_done[tbl] = data
				end

				data.stack = data.stack or {}

				if not data.stack[hash] then
					data.stack[hash] = {}
					data.stacki = data.stacki or {}
					table.insert(data.stacki, data.stack[hash])
				end

				falsy_union:SetParentTable(tbl, key)
				truthy_union:SetParentTable(tbl, key)

				for i = #data.stack[hash], 1, -1 do
					local tracked = data.stack[hash][i]

					if tracked.truthy_falsy then table.remove(data.stack[hash], i) end
				end

				table.insert(
					data.stack[hash],
					{
						key = key,
						truthy = truthy_union,
						falsy = falsy_union,
						inverted = self:IsInvertedExpressionContext(),
						truthy_falsy = truthy_falsy,
						scope = scope,
					}
				)
			end

			function META:GetTrackedTableWithKey(tbl, key)
				local hash = key:GetHashForMutationTracking()

				if hash == nil then return end

				local data = self.tracked_tables_done and self.tracked_tables_done[tbl]

				if not data then return end

				local stack = data.stack and data.stack[hash]

				if not stack then return end

				if self:IsInvertedExpressionContext() then
					if self:IsTruthyExpressionContext() then
						return stack[#stack].falsy
					elseif self:IsFalsyExpressionContext() then
						return stack[#stack].truthy
					end
				else
					if self:IsTruthyExpressionContext() then
						return stack[#stack].truthy
					elseif self:IsFalsyExpressionContext() then
						return stack[#stack].falsy
					end
				end
			end

			function META:GetTrackedTables(scope)
				local tables = {}

				if self.tracked_tables then
					scope = scope or self:GetScope()

					for _, data in ipairs(self.tracked_tables) do
						if data.stack then
							for _, stack in ipairs(data.stacki) do
								local new_stack = {}

								for i, v in ipairs(stack) do
									table.insert(new_stack, v)
								end

								table.insert(
									tables,
									{
										obj = data.tbl,
										key = stack[#stack].key,
										stack = new_stack,
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
					self.tracked_tables_done = false
					self.tracked_tables = false
				end
			end
		end

		function META:ClearTracked()
			self:ClearTrackedUpvalues()
			self:ClearTrackedTables()
		end

		function META:StashTrackedChanges()
			self.track_stash[#self.track_stash + 1] = {
				self.tracked_tables,
				self.tracked_tables_done,
				self.tracked_upvalues,
				self.tracked_upvalues_done,
			}
		end

		function META:PopStashedTrackedChanges()
			local tip = #self.track_stash
			local t = self.track_stash[tip]
			self.track_stash[tip] = nil
			self.tracked_tables = t[1]
			self.tracked_tables_done = t[2]
			self.tracked_upvalues = t[3]
			self.tracked_upvalues_done = t[4]
		end

		--[[
			local x: 1 | 2 | 3

			if x == 1 then
				assert(x == 1)
			end
		]]
		local function collect_truthy_values(stack)
			if not stack then return end

			local values = {}

			if stack[#stack].truthy and stack[#stack].truthy.Type == "range" then
				values[1] = stack[#stack].truthy:Copy()
			else
				for _, entry in ipairs(stack) do
					if entry.truthy then table.insert(values, entry.truthy) end
				end
			end

			if #values == 0 then return end

			if #values == 1 then return values[1] end

			return Union(values)
		end

		local function collect_falsy_values(stack)
			if not stack then return end

			local values = {}

			for _, entry in ipairs(stack) do
				if entry.falsy then table.insert(values, entry.falsy) end
			end

			if #values == 0 then return end

			if #values == 1 then return values[1] end

			return Union(values)
		end

		function META:ApplyMutationsInIf(upvalues, tables)
			if upvalues then
				for _, data in ipairs(upvalues) do
					local obj = collect_truthy_values(data.stack)

					if obj then
						obj:SetUpvalue(data.upvalue)
						self:MutateUpvalue(data.upvalue, obj, true)
					end
				end
			end

			if tables then
				for _, data in ipairs(tables) do
					local obj = collect_truthy_values(data.stack)

					if obj then self:MutateTable(data.obj, data.key, obj, true) end
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
		]]
		function META:ApplyMutationsInIfElse(blocks)
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

							if
								data.stack[#data.stack] and
								data.stack[#data.stack].falsy and
								data.stack[#data.stack].falsy.Type == "range"
							then
								self:MutateUpvalue(data.upvalue, collect_falsy_values(data.stack), true)
							else
								self:MutateUpvalue(data.upvalue, union, true)
							end
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
		]]
		--[[
			local x: 1 | 2 | 3

			if x == 1 then else return end

			assert(x == 1)
		]]
		--[[
			local x: 1 | 2 | 3

			if x == 1 then error("!") end

			assert(x == 2 | 3)
		]]
		local function solve(data, scope, negate)
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

		function META:ApplyMutationsAfterStatement(scope, negate, upvalues, tables)
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
		end
	end
end
