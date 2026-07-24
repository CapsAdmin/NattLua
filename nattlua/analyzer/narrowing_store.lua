local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local shallow_copy = require("nattlua.other.tablex").copy
--[[
    Narrowing Store for NattLua analyzer

    Tracks truthy/falsy type narrowing through conditional branches:
    - Truthy/falsy union splitting via tracked objects and stacks
    - Expression context management (truthy/falsy/inverted)
    - Applying narrowed types in if/else/after-statement
    - Tuple sibling narrowing
    - Table index tracking
    - Stashing tracked changes
]]
local META = {}
META.__index = META

function META.new()
	local store = {
		tracked_objects = {},
		tracked_objects_done = {},
		track_stash = {},
		-- Context counters
		truthy_expression_depth = 0,
		falsy_expression_depth = 0,
		inverted_expression_depth = 0,
	}
	return setmetatable(store, META)
end

-- ----------------------------------------------------------------
-- Context management
-- ----------------------------------------------------------------
function META:PushTruthyExpressionContext()
	self.truthy_expression_depth = self.truthy_expression_depth + 1
end

function META:PopTruthyExpressionContext()
	self.truthy_expression_depth = self.truthy_expression_depth - 1
end

function META:IsTruthyExpressionContext()
	return self.truthy_expression_depth > 0
end

function META:PushFalsyExpressionContext()
	self.falsy_expression_depth = self.falsy_expression_depth + 1
end

function META:PopFalsyExpressionContext()
	self.falsy_expression_depth = self.falsy_expression_depth - 1
end

function META:IsFalsyExpressionContext()
	return self.falsy_expression_depth > 0
end

function META:PushInvertedExpressionContext()
	self.inverted_expression_depth = self.inverted_expression_depth + 1
end

function META:PopInvertedExpressionContext()
	self.inverted_expression_depth = self.inverted_expression_depth - 1
end

function META:IsInvertedExpressionContext()
	return self.inverted_expression_depth > 0
end

-- ----------------------------------------------------------------
-- Tracking
-- ----------------------------------------------------------------
function META:TrackUpvalueUnion(obj, truthy_union, falsy_union, inverted, analyzer)
	local upvalue = obj:GetUpvalue()

	if not upvalue then return false, "no upvalue" end

	local scope = analyzer:GetScope()

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

function META:TrackTableIndex(tbl, key, val, analyzer)
	val:SetParentTable(tbl, key)
	local truthy_union = val:GetTruthy()
	local falsy_union = val:GetFalsy()
	self:TrackTableIndexUnion(val, truthy_union, falsy_union, true, analyzer)
end

function META:TrackTableIndexUnion(obj, truthy_union, falsy_union, truthy_falsy, analyzer)
	local tbl_key = obj:GetParentTable()

	if not tbl_key then return end

	local tbl = tbl_key.table
	local key = tbl_key.key
	local hash = key:GetHashForMutationTracking()

	if hash == nil then return end

	local scope = analyzer:GetScope()

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

do
	local function track_tuple_sibling_narrowing(self, checked_upvalue, checked_val, analyzer)
		local source_info = checked_val:GetTupleSourceUnion()

		if not source_info then return end

		local source_union = source_info.union
		local checked_index = source_info.index
		local truthy_branches = {}
		local falsy_branches = {}

		for _, obj in ipairs(source_union:GetData()) do
			if obj.Type == "tuple" then
				local val_at_index = obj:GetWithNumber(checked_index)

				if val_at_index then
					if val_at_index:IsTruthy() then table.insert(truthy_branches, obj) end

					if val_at_index:IsFalsy() then table.insert(falsy_branches, obj) end
				else
					table.insert(falsy_branches, obj)
				end
			end
		end

		local scope = analyzer:GetScope()

		if not scope then return end

		local all_upvalues = scope:GetAllUpvaluesInScope()

		if not all_upvalues then return end

		for _, upv in ipairs(all_upvalues) do
			if upv ~= checked_upvalue then
				local sib_val = upv:GetValue()

				if sib_val and sib_val.Type == "union" then
					local sib_source = sib_val:GetTupleSourceUnion()

					if sib_source and sib_source.union == source_union then
						local sib_index = sib_source.index
						local truthy_vals = {}

						for _, branch in ipairs(truthy_branches) do
							local v = branch:GetWithNumber(sib_index)

							if v then
								table.insert(truthy_vals, v)
							else
								table.insert(truthy_vals, Nil())
							end
						end

						local falsy_vals = {}

						for _, branch in ipairs(falsy_branches) do
							local v = branch:GetWithNumber(sib_index)

							if v then
								table.insert(falsy_vals, v)
							else
								table.insert(falsy_vals, Nil())
							end
						end

						local truthy_union = #truthy_vals > 0 and Union(truthy_vals) or Union({Nil()})
						local falsy_union = #falsy_vals > 0 and Union(falsy_vals) or Union({Nil()})
						self:TrackUpvalueUnion(sib_val, truthy_union, falsy_union, nil, analyzer)
					end
				end
			end
		end
	end

	function META:TrackDependentUpvalues(obj, follow_intermediate, analyzer)
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

					self:TrackTableIndexUnion(obj, t, f, nil, analyzer)
				end

				local left_right = obj:GetLeftRightSource()

				if left_right then
					self:TrackDependentUpvalues(left_right.left, true, analyzer)
					self:TrackDependentUpvalues(left_right.right, true, analyzer)
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

			self:TrackUpvalueUnion(upvalue:GetValue(), t, f, nil, analyzer)
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

			self:TrackTableIndexUnion(val, t, f, nil, analyzer)
		end

		if val.Type == "union" and val:GetTupleSourceUnion() then
			track_tuple_sibling_narrowing(self, upvalue, val, analyzer)
		end

		if val.Type == "union" then
			local left_right = val:GetLeftRightSource()

			if left_right then
				self:TrackDependentUpvalues(left_right.left, true, analyzer)
				self:TrackDependentUpvalues(left_right.right, true, analyzer)
			end
		end
	end
end

do
	local function resolve_tracked_value(store, stack, set_upvalue_fn, upvalue)
		if store:IsInvertedExpressionContext() then
			if store:IsFalsyExpressionContext() then
				local val = stack[#stack].falsy

				if set_upvalue_fn then set_upvalue_fn(val, upvalue) end

				return val
			elseif store:IsTruthyExpressionContext() then
				local union = stack[#stack].truthy

				if union.Type == "union" and union:GetCardinality() == 0 then
					union = Union()

					for _, val in ipairs(stack) do
						union:AddType(val.truthy)
					end
				end

				if set_upvalue_fn then set_upvalue_fn(union, upvalue) end

				return union
			end
		else
			if store:IsTruthyExpressionContext() then
				local val = stack[#stack].truthy

				if set_upvalue_fn then set_upvalue_fn(val, upvalue) end

				return val
			elseif store:IsFalsyExpressionContext() then
				local union = stack[#stack].falsy

				if union.Type == "union" and union:GetCardinality() == 0 then
					union = Union()

					for _, val in ipairs(stack) do
						union:AddType(val.falsy)
					end
				end

				if set_upvalue_fn then set_upvalue_fn(union, upvalue) end

				return union
			end
		end
	end

	function META:GetTrackedUpvalue(obj)
		local upvalue = obj:GetUpvalue()
		local data = self.tracked_objects_done[upvalue]
		local stack = data and data.stack

		if not stack then return end

		local function set_upvalue(val, upvalue)
			val:SetUpvalue(upvalue)
		end

		return resolve_tracked_value(self, stack, set_upvalue, upvalue)
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
end

function META:GetTrackedObjects(old_upvalues, scope, analyzer)
	scope = scope or analyzer:GetScope()
	local objects = {}
	local translate = {}

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

function META:ClearScopedTrackedObjects(scope)
	if scope.TrackedObjects then
		for _, obj in ipairs(scope.TrackedObjects) do
			obj.mutator:ClearTracked()
		end
	end
end

do
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

	function META:ApplyMutationsInIf(tracked_objects, analyzer)
		if not tracked_objects then return end

		for _, data in ipairs(tracked_objects) do
			local obj = collect_truthy_values(data.stack)

			if not obj then continue end

			if data.kind == "upvalue" then
				obj:SetUpvalue(data.upvalue)
				analyzer:MutateUpvalue(data.upvalue, obj, true)
			elseif data.kind == "table" then
				analyzer:MutateTable(data.obj, data.key, obj, true)
			end
		end
	end
end

do
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

	function META:ApplyMutationsInIfElse(blocks, analyzer)
		for i, block in ipairs(blocks) do
			if block.tracked_objects then
				for _, data in ipairs(block.tracked_objects) do
					if data.stack then
						if data.kind == "upvalue" then
							local union = analyzer:GetMutatedUpvalue(data.upvalue)

							if union.Type == "union" then
								for _, v in ipairs(data.stack) do
									union:RemoveType(v.truthy)
								end

								union:SetUpvalue(data.upvalue)
							end

							if
								data.stack[#data.stack] and
								data.stack[#data.stack].falsy and
								(
									data.stack[#data.stack].falsy.Type == "range" or
									(
										union.Type == "union" and
										union:IsEmpty()
									)
								)
							then
								analyzer:MutateUpvalue(data.upvalue, collect_falsy_values(data.stack), true)
							else
								analyzer:MutateUpvalue(data.upvalue, union, true)
							end
						elseif data.kind == "table" then
							local union = analyzer:GetMutatedTableValue(data.obj, data.key)

							if union then
								if union.Type == "union" then
									for _, v in ipairs(data.stack) do
										union:RemoveType(v.truthy)
									end
								end

								if union.Type == "union" and union:IsEmpty() then
									local falsy = collect_falsy_values(data.stack)

									if falsy then
										analyzer:MutateTable(data.obj, data.key, falsy, true)
									else
										analyzer:MutateTable(data.obj, data.key, union, true)
									end
								else
									analyzer:MutateTable(data.obj, data.key, union, true)
								end
							end
						end
					end
				end
			end
		end
	end
end

do
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

	function META:ApplyMutationsAfterStatement(scope, negate, tracked_objects, analyzer)
		if not tracked_objects then return end

		for _, data in ipairs(tracked_objects) do
			local val = solve(data, scope, negate)

			if val then
				if data.kind == "upvalue" then
					val:SetUpvalue(data.upvalue)
					analyzer:MutateUpvalue(data.upvalue, val, true)
				elseif data.kind == "table" then
					analyzer:MutateTable(data.obj, data.key, val, true)
				end
			end
		end
	end
end

function META:SnapshotForNot()
	local snapshot = {}
	snapshot.n = #self.tracked_objects

	for i, data in ipairs(self.tracked_objects) do
		snapshot[i] = data.stack and #data.stack or 0
	end

	return snapshot
end

function META:SwapNotNarrowing(pre_snapshot, post_snapshot)
	-- swap for entries added during sub-expression evaluation
	for i = pre_snapshot.n + 1, post_snapshot.n do
		local data = self.tracked_objects[i]

		if data and data.stack then
			for _, entry in ipairs(data.stack) do
				entry.truthy, entry.falsy = entry.falsy, entry.truthy
			end
		end
	end

	-- swap for new stack entries in existing tracked objects
	for i = 1, pre_snapshot.n do
		local data = self.tracked_objects[i]

		if data and data.stack then
			for j = (pre_snapshot[i] or 0) + 1, (post_snapshot[i] or 0) do
				data.stack[j].truthy, data.stack[j].falsy = data.stack[j].falsy, data.stack[j].truthy
			end
		end
	end
end

function META:DumpUpvalueTracking(obj)
	local upvalue = obj:GetUpvalue()

	if not upvalue then return "no upvalue" end

	if not self.tracked_objects_done[upvalue] then return "no upvalues done" end

	local data = self.tracked_objects_done[upvalue]

	if not data.stack then return "no stack" end

	local str = tostring(data.upvalue) .. "\n"

	for i, v in ipairs(data.stack) do
		str = str .. "T=" .. tostring(v.truthy:Simplify()) .. " F=" .. tostring(v.falsy:Simplify()) .. "\n"
	end

	print(str)
end

return META
