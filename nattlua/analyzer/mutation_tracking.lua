local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.range").LNumberRange
local shallow_copy = require("nattlua.other.tablex").copy
return function(META--[[#: any]])
	META:AddInitializer(function(self)
		self.tracked_objects = {}
		self.tracked_objects_done = {}
	end)

	function META:GetArrayLengthFromTable(tbl)
		if tbl.Type ~= "table" then
			if tbl.GetArrayLength then return tbl:GetArrayLength() end

			return LNumber(0)
		end

		local len_type = tbl:GetArrayLength()
		local scope = self:GetScope()
		local len = 0

		if len_type.Type ~= "number" or not len_type:IsLiteral() then
			return len_type
		end

		len = (len_type--[[# as any]]):GetData()
		-- grow
		local cur = len + 1
		local max_grow = 100

		while cur < len + max_grow do
			local val = tbl:GetMutatedValue(LNumber(cur), scope)

			if not val or (val.Type == "symbol" and val:GetData() == nil) then
				break
			end

			cur = cur + 1
		end

		local final_len = cur - 1
		-- shrink
		cur = final_len

		while cur > 0 do
			local val = tbl:GetMutatedValue(LNumber(cur), scope)

			if val and val.Type == "symbol" and val:GetData() == nil then
				cur = cur - 1
			else
				break
			end
		end

		final_len = cur

		if final_len == 0 and not len_type:IsLiteral() then return len_type end

		return LNumber(final_len)
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
				obj:ClearTrackedMutations()
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
			function META:TrackDependentUpvalues(obj, follow_intermediate)
				local upvalue = obj:GetUpvalue()

				if not upvalue then
					-- Follow LeftRightSource chains only when traversing from a
					-- stored variable's chain (not from direct condition expressions)
					if follow_intermediate and obj.Type == "union" then
						-- Check for table field narrowing data (e.g., t.x had ~= nil comparison)
						local stored_tf = obj:GetStoredTruthyFalsy()

						if stored_tf and obj:GetParentTable() then
							local t, f = stored_tf.truthy, stored_tf.falsy

							if self:IsInvertedExpressionContext() then t, f = f, t end

							self:TrackTableIndexUnion(obj, t, f)
						end

						local left_right = obj:GetLeftRightSource()

						if left_right then
							self:TrackDependentUpvalues(left_right.left, true)
							self:TrackDependentUpvalues(left_right.right, true)
						end
					end

					return
				end

				local val = upvalue:GetValue()
				local truthy_falsy = upvalue:GetTruthyFalsyUnion()

				if truthy_falsy then
					local t, f = truthy_falsy.truthy, truthy_falsy.falsy

					-- When inside a `not` prefix, the condition meaning is inverted:
					-- `local c = x == nil; if not c then` means x ~= nil in the body,
					-- so we swap truthy/falsy from the stored comparison.
					if self:IsInvertedExpressionContext() then t, f = f, t end

					self:TrackUpvalueUnion(upvalue:GetValue(), t, f)
				end

				-- If the upvalue's value has a ParentTable reference (e.g., local val = t.foo),
				-- also narrow the table field when the alias is checked.
				if val.Type == "union" and val:GetParentTable() then
					local stored_tf = val:GetStoredTruthyFalsy()
					local t, f

					if stored_tf then
						-- Use comparison-derived truthy/falsy (from ~= nil etc.)
						t, f = stored_tf.truthy, stored_tf.falsy
					else
						-- Use truthiness-based split (from plain `if val then`)
						t, f = val:GetTruthy(), val:GetFalsy()
					end

					if self:IsInvertedExpressionContext() then t, f = f, t end

					self:TrackTableIndexUnion(val, t, f)
				end

				if val.Type == "union" then
					local left_right = val:GetLeftRightSource()

					if left_right then
						self:TrackDependentUpvalues(left_right.left, true)
						self:TrackDependentUpvalues(left_right.right, true)
					end
				end
			end

			-- Shared internal: resolve truthy/falsy based on expression context
			local function resolve_tracked_value(self, stack, set_upvalue_fn)
				if self:IsInvertedExpressionContext() then
					if self:IsFalsyExpressionContext() then
						local val = stack[#stack].falsy

						if set_upvalue_fn then set_upvalue_fn(val) end

						return val
					elseif self:IsTruthyExpressionContext() then
						local union = stack[#stack].truthy

						if union.Type == "union" and union:GetCardinality() == 0 then
							union = Union()

							for _, val in ipairs(stack) do
								union:AddType(val.truthy)
							end
						end

						if set_upvalue_fn then set_upvalue_fn(union) end

						return union
					end
				else
					if self:IsTruthyExpressionContext() then
						local val = stack[#stack].truthy

						if set_upvalue_fn then set_upvalue_fn(val) end

						return val
					elseif self:IsFalsyExpressionContext() then
						local union = stack[#stack].falsy

						if union.Type == "union" and union:GetCardinality() == 0 then
							union = Union()

							for _, val in ipairs(stack) do
								union:AddType(val.falsy)
							end
						end

						if set_upvalue_fn then set_upvalue_fn(union) end

						return union
					end
				end
			end

			-- Track an upvalue's truthy/falsy narrowing
			function META:TrackUpvalueUnion(obj, truthy_union, falsy_union, inverted)
				local upvalue = obj:GetUpvalue()

				if not upvalue then return false, "no upvalue" end

				local scope = self:GetScope()

				if not scope then return false, "no scope" end

				local data = self.tracked_objects_done[upvalue]

				if not data then
					data = {kind = "upvalue", upvalue = upvalue, stack = {}}
					table.insert(self.tracked_objects, data)
					self.tracked_objects_done[upvalue] = data
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

				if not self.tracked_objects_done[upvalue] then
					return "no upvalues done"
				end

				local data = self.tracked_objects_done[upvalue]

				if not data.stack then return "no stack" end

				local str = tostring(data.upvalue) .. "\n"

				for i, v in ipairs(data.stack) do
					str = str .. "T=" .. tostring(v.truthy:Simplify()) .. " F=" .. tostring(v.falsy:Simplify()) .. "\n"
				end

				print(str)
			end

			function META:GetTrackedUpvalue(obj)
				local upvalue = obj:GetUpvalue()
				local data = self.tracked_objects_done[upvalue]
				local stack = data and data.stack

				if not stack then return end

				return resolve_tracked_value(self, stack, function(val)
					val:SetUpvalue(upvalue)
				end)
			end

			-- Track a table index's truthy/falsy narrowing
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

				-- Use a compound key for table+hash in the done map
				local lookup_key = tbl
				local data = self.tracked_objects_done[lookup_key]

				if not data then
					data = {kind = "table", tbl = tbl}
					table.insert(self.tracked_objects, data)
					self.tracked_objects_done[lookup_key] = data
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

				local data = self.tracked_objects_done[tbl]

				if not data then return end

				local stack = data.stack and data.stack[hash]

				if not stack then return end

				return resolve_tracked_value(self, stack, nil)
			end

			-- Unified getter: returns tracked objects list for scope storage
			function META:GetTrackedObjects(old_upvalues, scope)
				local objects = {}
				local translate = {}
				scope = scope or self:GetScope()

				if old_upvalues then
					for i, upvalue in ipairs(scope.upvalues.runtime.list) do
						local old = old_upvalues[i]
						translate[old] = upvalue
					end
				end

				for _, data in ipairs(self.tracked_objects) do
					if data.kind == "upvalue" then
						local stack = data.stack
						local upvalue = data.upvalue

						if old_upvalues then upvalue = translate[upvalue] end

						-- stack is needed to simply track upvalues used, even if they were not mutated for warnings
						if upvalue then
							table.insert(
								objects,
								{kind = "upvalue", upvalue = upvalue, stack = stack and shallow_copy(stack)}
							)
						end
					elseif data.kind == "table" then
						if data.stack then
							for _, stack in ipairs(data.stacki) do
								local new_stack = {}

								for i, v in ipairs(stack) do
									table.insert(new_stack, v)
								end

								table.insert(
									objects,
									{
										kind = "table",
										obj = data.tbl,
										key = stack[#stack].key,
										stack = new_stack,
									}
								)
							end
						end
					end
				end

				return objects
			end

			function META:ClearTracked()
				self.tracked_objects_done = {}
				self.tracked_objects = {}
			end

			function META:StashTrackedChanges()
				self.track_stash[#self.track_stash + 1] = {
					self.tracked_objects,
					self.tracked_objects_done,
				}
			end

			function META:PopStashedTrackedChanges()
				local tip = #self.track_stash
				local t = self.track_stash[tip]
				self.track_stash[tip] = nil
				self.tracked_objects = t[1]
				self.tracked_objects_done = t[2]
			end
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

		local function apply_mutation(self, data)
			local obj = collect_truthy_values(data.stack)

			if not obj then return end

			if data.kind == "upvalue" then
				obj:SetUpvalue(data.upvalue)
				self:MutateUpvalue(data.upvalue, obj, true)
			elseif data.kind == "table" then
				self:MutateTable(data.obj, data.key, obj, true)
			end
		end

		function META:ApplyMutationsInIf(tracked_objects)
			if not tracked_objects then return end

			for _, data in ipairs(tracked_objects) do
				apply_mutation(self, data)
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
				if block.tracked_objects then
					for _, data in ipairs(block.tracked_objects) do
						if data.stack then
							if data.kind == "upvalue" then
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
							elseif data.kind == "table" then
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

		function META:ApplyMutationsAfterStatement(scope, negate, tracked_objects)
			if not tracked_objects then return end

			for _, data in ipairs(tracked_objects) do
				local val = solve(data, scope, negate)

				if val then
					if data.kind == "upvalue" then
						val:SetUpvalue(data.upvalue)
						self:MutateUpvalue(data.upvalue, val, true)
					elseif data.kind == "table" then
						self:MutateTable(data.obj, data.key, val, true)
					end
				end
			end
		end
	end
end
