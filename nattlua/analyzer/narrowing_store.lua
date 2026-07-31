local ipairs = _G.ipairs
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local shallow_copy = require("nattlua.other.tablex").copy
local META = {}
META.__index = META

function META.new()
	return setmetatable(
		{
			tracked_objects = {},
			tracked_objects_done = {},
			track_stash = {},
			truthy_depth = 0,
			falsy_depth = 0,
			inverted_depth = 0,
		},
		META
	)
end

function META:PushTruthyExpressionContext()
	self.truthy_depth = self.truthy_depth + 1
end

function META:PopTruthyExpressionContext()
	self.truthy_depth = self.truthy_depth - 1
end

function META:IsTruthyExpressionContext()
	return self.truthy_depth > 0
end

function META:PushFalsyExpressionContext()
	self.falsy_depth = self.falsy_depth + 1
end

function META:PopFalsyExpressionContext()
	self.falsy_depth = self.falsy_depth - 1
end

function META:IsFalsyExpressionContext()
	return self.falsy_depth > 0
end

function META:PushInvertedExpressionContext()
	self.inverted_depth = self.inverted_depth + 1
end

function META:PopInvertedExpressionContext()
	self.inverted_depth = self.inverted_depth - 1
end

local function swap_if_inverted(store, a, b)
	return store.inverted_depth % 2 == 1 and b or a,
	store.inverted_depth % 2 == 1 and a or b
end

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
			truthy = swap_if_inverted(self, truthy_union, falsy_union),
			falsy = swap_if_inverted(self, falsy_union, truthy_union),
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

	local tbl, key = tbl_key.table, tbl_key.key
	local hash = key:GetHashForMutationTracking()

	if hash == nil then return end

	local scope = analyzer:GetScope()

	if not scope then return end

	local data = self.tracked_objects_done[tbl]

	if not data then
		data = {kind = "table", tbl = tbl}
		table.insert(self.tracked_objects, data)
		self.tracked_objects_done[tbl] = data
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
			truthy = swap_if_inverted(self, truthy_union, falsy_union),
			falsy = swap_if_inverted(self, falsy_union, truthy_union),
			inverted = false,
			truthy_falsy = truthy_falsy,
			scope = scope,
		}
	)
end

do
	local function collect(branch, idx)
		local vals = {}

		for _, b in ipairs(branch) do
			table.insert(vals, b:GetWithNumber(idx) or Nil())
		end

		return #vals > 0 and Union(vals) or Union({Nil()})
	end

	local function track_tuple_sibling_narrowing(self, checked_upvalue, checked_val, analyzer)
		local source_info = checked_val:GetTupleSourceUnion()

		if not source_info then return end

		local source_union, checked_index = source_info.union, source_info.index
		local truthy_branches, falsy_branches = {}, {}

		for _, obj in ipairs(source_union:GetData()) do
			if obj.Type == "tuple" then
				local v = obj:GetWithNumber(checked_index)

				if v then
					if v:IsTruthy() then table.insert(truthy_branches, obj) end

					if v:IsFalsy() then table.insert(falsy_branches, obj) end
				else
					table.insert(falsy_branches, obj)
				end
			end
		end

		local scope = analyzer:GetScope()

		if not scope then return end

		for _, upv in ipairs(scope:GetAllUpvaluesInScope()) do
			if upv ~= checked_upvalue then
				local sib_val = upv:GetValue()

				if sib_val and sib_val.Type == "union" then
					local sib_source = sib_val:GetTupleSourceUnion()

					if sib_source and sib_source.union == source_union then
						self:TrackUpvalueUnion(
							sib_val,
							collect(truthy_branches, sib_source.index),
							collect(falsy_branches, sib_source.index),
							nil,
							analyzer
						)
					end
				end
			end
		end
	end

	function META:TrackDependentUpvalues(obj, follow_intermediate, analyzer)
		local upvalue = obj:GetUpvalue()

		if not upvalue then
			if follow_intermediate and obj.Type == "union" then
				local stored_tf = obj:GetStoredTruthyFalsy()

				if stored_tf and obj:GetParentTable() then
					self:TrackTableIndexUnion(obj, stored_tf.truthy, stored_tf.falsy, nil, analyzer)
				end

				local lr = obj:GetLeftRightSource()

				if lr then
					self:TrackDependentUpvalues(lr.left, true, analyzer)
					self:TrackDependentUpvalues(lr.right, true, analyzer)
				end
			end

			return
		end

		local val = upvalue:GetValue()
		local tf = upvalue:GetTruthyFalsyUnion()

		if tf then
			self:TrackUpvalueUnion(val, tf.truthy, tf.falsy, nil, analyzer)
		end

		if val.Type == "union" and val:GetParentTable() then
			local stored = val:GetStoredTruthyFalsy()
			self:TrackTableIndexUnion(
				val,
				stored and stored.truthy or val:GetTruthy(),
				stored and stored.falsy or val:GetFalsy(),
				nil,
				analyzer
			)
		end

		if val.Type == "union" and val:GetTupleSourceUnion() then
			track_tuple_sibling_narrowing(self, upvalue, val, analyzer)
		end

		if val.Type == "union" then
			local lr = val:GetLeftRightSource()

			if lr then
				self:TrackDependentUpvalues(lr.left, true, analyzer)
				self:TrackDependentUpvalues(lr.right, true, analyzer)
			end
		end
	end
end

do
	local function resolve_tracked_value(store, stack, set_upvalue_fn, upvalue)
		local top = stack[#stack]

		if store:IsTruthyExpressionContext() then
			local val = top.truthy

			if set_upvalue_fn then set_upvalue_fn(val, upvalue) end

			return val
		elseif store:IsFalsyExpressionContext() then
			local union = top.falsy

			if union.Type == "union" and union:GetCardinality() == 0 then
				union = Union()

				for _, entry in ipairs(stack) do
					union:AddType(entry.falsy)
				end
			end

			if set_upvalue_fn then set_upvalue_fn(union, upvalue) end

			return union
		end
	end

	function META:GetTrackedUpvalue(obj)
		local upvalue = obj:GetUpvalue()
		local stack = self.tracked_objects_done[upvalue]

		if not stack then return end

		stack = stack.stack

		if not stack then return end

		return resolve_tracked_value(self, stack, function(val, uv)
			val:SetUpvalue(uv)
		end, upvalue)
	end

	function META:GetTrackedTableWithKey(tbl, key)
		local hash = key:GetHashForMutationTracking()

		if not hash then return end

		local data = self.tracked_objects_done[tbl]

		if not data or not data.stack then return end

		local stack = data.stack[hash]

		if not stack then return end

		return resolve_tracked_value(self, stack, nil)
	end
end

function META:GetTrackedObjects(old_upvalues, scope, analyzer)
	scope = scope or analyzer:GetScope()
	local objects, translate = {}, nil

	if old_upvalues then
		translate = {}

		for i, upvalue in ipairs(scope.upvalues.runtime.list) do
			translate[old_upvalues[i]] = upvalue
		end
	end

	for _, data in ipairs(self.tracked_objects) do
		if data.kind == "upvalue" then
			local upvalue = translate and translate[data.upvalue] or data.upvalue

			if upvalue and data.stack then
				table.insert(objects, {kind = "upvalue", upvalue = upvalue, stack = shallow_copy(data.stack)})
			end
		elseif data.kind == "table" and data.stack then
			for _, stack in ipairs(data.stacki) do
				table.insert(
					objects,
					{
						kind = "table",
						obj = data.tbl,
						key = stack[#stack].key,
						stack = shallow_copy(stack),
					}
				)
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
	self.track_stash[#self.track_stash + 1] = {self.tracked_objects, self.tracked_objects_done}
end

function META:PopStashedTrackedChanges()
	local t = self.track_stash[#self.track_stash]
	self.track_stash[#self.track_stash] = nil
	self.tracked_objects, self.tracked_objects_done = t[1], t[2]
end

function META:ClearScopedTrackedObjects(scope)
	if scope.TrackedObjects then
		for _, obj in ipairs(scope.TrackedObjects) do
			obj.mutator:ClearTracked()
		end
	end
end

do
	local function collect_values(stack, field, skip_applied)
		if not stack or #stack == 0 then return end

		local values = {}

		for _, entry in ipairs(stack) do
			local v = entry[field]

			if skip_applied and entry.applied then goto continue end

			if v then table.insert(values, v) end

			::continue::
		end

		if #values == 0 then return end

		if #values == 1 then return values[1] end

		return Union(values)
	end

	function META:ApplyMutationsInIf(tracked_objects, analyzer)
		if not tracked_objects then return end

		for _, data in ipairs(tracked_objects) do
			local stack = data.stack
			local obj

			-- Range types are returned directly without collection
			if
				stack and
				#stack > 0 and
				stack[#stack].truthy and
				stack[#stack].truthy.Type == "range"
			then
				obj = stack[#stack].truthy:Copy()
			else
				obj = collect_values(stack, "truthy", true)
			end

			if not obj then goto continue end

			if data.kind == "upvalue" then
				obj:SetUpvalue(data.upvalue)
				analyzer:MutateUpvalue(data.upvalue, obj, true)
			elseif data.kind == "table" then
				analyzer:MutateTable(data.obj, data.key, obj, true)
			end

			::continue::
		end
	end

	function META:ApplyMutationsInIfElse(blocks, analyzer)
		for _, block in ipairs(blocks) do
			if not block.tracked_objects then goto continue_block end

			for _, data in ipairs(block.tracked_objects) do
				if not data.stack then goto continue end

				if data.kind == "upvalue" then
					local union = analyzer:GetMutatedUpvalue(data.upvalue)

					if union and union.Type == "union" then
						for _, v in ipairs(data.stack) do
							union:RemoveType(v.truthy)
						end

						union:SetUpvalue(data.upvalue)
					end

					local top_falsy = data.stack[#data.stack].falsy

					if
						top_falsy and
						(
							top_falsy.Type == "range" or
							(
								union and
								union.Type == "union" and
								union:IsEmpty()
							)
						)
					then
						local falsy = collect_values(data.stack, "falsy")

						if falsy then analyzer:MutateUpvalue(data.upvalue, falsy, true) end
					elseif union then
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
							local falsy = collect_values(data.stack, "falsy")
							analyzer:MutateTable(data.obj, data.key, falsy or union, true)
						else
							analyzer:MutateTable(data.obj, data.key, union, true)
						end
					end
				end

				::continue::
			end

			::continue_block::
		end
	end
end

do
	local function solve(data, scope, negate)
		local stack = data.stack

		if not stack or #stack == 0 then return end

		local val = (
				negate and
				not scope:IsElseConditionalScope()
				and
				not stack[#stack].inverted
			)
			and
			stack[#stack].falsy or
			stack[#stack].truthy

		if not val then return end

		if val.Type == "union" and val:IsEmpty() then return end

		if val.Type == "union" and #val:GetData() == 1 then val = val:GetData()[1] end

		return val
	end

	function META:ApplyMutationsAfterStatement(scope, negate, tracked_objects, analyzer)
		if not tracked_objects then return end

		for _, data in ipairs(tracked_objects) do
			local val = solve(data, scope, negate)

			if not val then goto continue end

			if data.kind == "upvalue" then
				val:SetUpvalue(data.upvalue)
				analyzer:MutateUpvalue(data.upvalue, val, true)
			elseif data.kind == "table" then
				analyzer:MutateTable(data.obj, data.key, val, true)
			end

			if data.stack and #data.stack > 0 then
				data.stack[#data.stack].applied = true
			end

			::continue::
		end
	end
end

function META:DumpUpvalueTracking(obj)
	local upvalue = obj:GetUpvalue()

	if not upvalue then return "no upvalue" end

	local data = self.tracked_objects_done[upvalue]

	if not data or not data.stack then return "no tracking data" end

	local str = tostring(data.upvalue) .. "\n"

	for _, v in ipairs(data.stack) do
		str = str .. "T=" .. tostring(v.truthy:Simplify()) .. " F=" .. tostring(v.falsy:Simplify()) .. "\n"
	end

	print(str)
end

return META
