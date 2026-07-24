local ipairs = _G.ipairs
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local error_messages = require("nattlua.error_messages")
local M = {}

do
	local ipairs = _G.ipairs
	local table = _G.table
	local table_remove = _G.table.remove
	local Union = require("nattlua.types.union").Union
	local shallow_copy = require("nattlua.other.tablex").copy

	local function is_part_of_sibling_scope(mut, scope)
		if scope == mut.scope then return false end

		if scope:BelongsToIfStatement(mut.scope) then return true end

		return mut.from_tracking and not mut.scope:Contains(scope)
	end

	local function certain_override(mut, scope, obj, test_scope_a)
		if mut.scope == scope then return false end

		local test_scope_b = mut.scope:FindFirstConditionalScope()
		return test_scope_b and
			test_scope_b ~= test_scope_a and
			obj.Type ~= "table" and
			test_scope_a:TracksSameAs(test_scope_b, obj)
	end

	-- Filter out mutations that are contained in other mutations' scopes
	local function filter_non_contained_mutations(mutations, scope)
		local filtered = {}

		for i = 1, #mutations do
			local mut = mutations[i]

			if not is_part_of_sibling_scope(mut, scope) then
				local should_keep = true

				-- Check if this mutation is contained in later mutations' scopes
				for j = i + 1, #mutations do
					if mutations[j].scope:Contains(mut.scope) then
						if
							not mut.scope:IsLoopScope() or
							(
								mut.scope:GetNearestLoopScope() == scope:GetNearestLoopScope()
							)
						then
							should_keep = false

							break
						end
					end
				end

				if should_keep then table.insert(filtered, mut) end
			end
		end

		return filtered
	end

	-- Handle else conditional cases by removing redundant certain mutations
	local function handle_else_conditionals(mutations, scope)
		local result = shallow_copy(mutations)

		for i = #result, 1, -1 do
			local mut = result[i]

			if mut.scope:IsElseConditionalScope() then
				-- Find first non-certain mutation before else
				for j = i - 1, 1, -1 do
					local prev_mut = result[j]

					if
						not prev_mut.scope:BelongsToIfStatement(scope) and
						not prev_mut.scope:IsCertainFromScope(scope)
					then
						-- Remove redundant certain mutations
						for k = j, 1, -1 do
							if result[k].scope:IsCertainFromScope(scope) then
								table.remove(result, k)
							end
						end

						break
					end
				end

				break
			end
		end

		return result
	end

	-- Process final mutations based on certain overrides
	local function process_certain_overrides(mutations, scope, obj)
		local test_scope_a = scope:FindFirstConditionalScope()

		if test_scope_a then
			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if
					certain_override(mut, scope, obj, test_scope_a) or
					mut.scope:IsCertainFromScope(scope)
				then
					-- Create new array with remaining mutations
					local remaining = {}

					for j = i, #mutations do
						table.insert(remaining, mutations[j])
					end

					return remaining
				end
			end
		end

		return mutations
	end

	local function remove_redundant_mutations(mutations, scope, obj)
		-- Early exit for simple cases
		if #mutations <= 1 then return mutations end

		-- First pass: Filter out sibling scope mutations and contained scopes
		local filtered = filter_non_contained_mutations(mutations, scope)

		if not filtered or #filtered == 0 then return nil end

		-- Second pass: Handle else conditional cases
		local after_else_handling = handle_else_conditionals(filtered, scope)

		if #after_else_handling == 0 then return nil end

		-- Final pass: Process based on certain overrides
		return process_certain_overrides(after_else_handling, scope, obj)
	end

	local function get_value(mut)
		if mut.value.Type == "union" and #mut.value:GetData() == 1 then
			return mut.value:GetData()[1]
		end

		return mut.value
	end

	-- Check if union has both generic number and range types
	local function has_generic_number_and_range(data)
		local has_generic_number, has_range = false, false

		for _, elem in ipairs(data) do
			if elem.Type == "number" and not elem:IsLiteral() then
				has_generic_number = true
			elseif elem.Type == "range" then
				has_range = true
			end

			if has_generic_number and has_range then return true end
		end

		return false
	end

	-- Narrow: remove generic number when range is present (inside if-block)
	local function narrow_number_ranges(union, first)
		if first.Type ~= "number" or first:IsLiteral() or union.Type ~= "union" then
			return
		end

		local data = union:GetData()

		if has_generic_number_and_range(data) then
			for i = #data, 1, -1 do
				if data[i].Type == "number" and not data[i]:IsLiteral() then
					union:RemoveType(data[i])
				end
			end
		end
	end

	-- Widen: remove ranges when generic number is present (after if-blocks)
	local function widen_number_ranges(union, first)
		if first.Type ~= "number" or first:IsLiteral() or union.Type ~= "union" then
			return
		end

		local data = union:GetData()

		if has_generic_number_and_range(data) then
			for i = #data, 1, -1 do
				if data[i].Type == "range" then union:RemoveType(data[i]) end
			end
		end
	end

	-- Build union from single mutation (early exit path)
	local function build_union_from_value(value)
		if value.Type == "union" then return value:Copy() end

		return Union({value})
	end

	-- Get narrowed value from conditional tracking data
	local function get_conditional_value(stack_entry, is_else)
		if is_else then return stack_entry.falsy end

		return stack_entry.truthy
	end

	-- Apply narrowing for upvalue in if-statement scope
	local function narrow_upvalue(union, mut, obj)
		if mut.scope:GetStatementType() ~= "statement_if" then return end

		local data = mut.scope:FindTrackedUpvalue(obj)

		if not data or not data.stack then return end

		local val = get_conditional_value(data.stack[#data.stack], mut.scope:IsElseConditionalScope())

		if val and (val.Type ~= "union" or not val:IsEmpty()) then
			union:RemoveType(val)
		end
	end

	-- Apply narrowing for table in if-statement scope
	local function narrow_table(union, mut, obj)
		if mut.scope:GetStatementType() ~= "statement_if" or not mut.key then
			return false
		end

		local data = mut.scope:FindTrackedTable(obj, mut.key)

		if not data or not data.stack then return false end

		local entry = data.stack[#data.stack]
		local is_else = mut.scope:IsElseConditionalScope()
		local val = is_else and
			(
				entry.inverted and
				entry.truthy or
				entry.falsy
			)
			or
			(
				entry.inverted and
				entry.falsy or
				entry.truthy
			)

		if val and (val.Type ~= "union" or not val:IsEmpty()) then
			union:RemoveType(val)
			return true
		end

		return false
	end

	function M.SolveMutations(mutations, scope, obj)
		-- common case early exit, if the last mutation was done in the same scope
		if mutations[#mutations] and mutations[#mutations].scope == scope then
			local first = get_value(mutations[#mutations])
			local union = build_union_from_value(first)

			if obj.Type == "upvalue" then union:SetUpvalue(obj) end

			narrow_number_ranges(union, first)
			return union:Simplify()
		end

		local mutations = remove_redundant_mutations(mutations, scope, obj)

		if not mutations then return end

		local first = get_value(mutations[1])
		local union = first.Type == "union" and first:Copy() or Union()
		local start = first.Type == "union" and 2 or 1

		for i = start, #mutations do
			local mut = mutations[i]
			local value = get_value(mut)

			if i > 1 then
				if obj.Type == "upvalue" then
					narrow_upvalue(union, mut, obj)
				elseif obj.Type == "table" then
					local narrowed = narrow_table(union, mut, obj)

					if
						not narrowed and
						value.Type ~= "any" and
						mutations[1].value.Type ~= "union" and
						mutations[1].value.Type ~= "function" and
						union:HasTypeObject(value)
					then
						union:RemoveType(mutations[1].value)
					end
				end
			end

			union:AddType(value)
		end

		if obj.Type == "upvalue" then union:SetUpvalue(obj) end

		widen_number_ranges(union, first)
		return union:Simplify()
	end
end

do -- upvalues
	local LinearMutator = {}
	LinearMutator.__index = LinearMutator

	function LinearMutator.New()
		return setmetatable({
			mutations = false,
		}, LinearMutator)
	end

	function LinearMutator:Init()
		self.mutations = self.mutations or {}
	end

	function LinearMutator:Track(entry)
		self:Init()

		if self.mutations[100] then return false, error_messages.too_many_mutations() end

		table_insert(self.mutations, entry)
		return true
	end

	function LinearMutator:Resolve(scope, obj)
		return M.SolveMutations(self.mutations, scope, obj)
	end

	function LinearMutator:Clear()
		self.mutations = false
	end

	function LinearMutator:HasMutations()
		return self.mutations ~= false
	end

	function LinearMutator:ClearTracked()
		local mutations = self.mutations or self:Get()

		for i = #mutations, 1, -1 do
			if mutations[i].from_tracking then table_remove(mutations, i) end
		end
	end

	function LinearMutator:Get()
		return self.mutations
	end

	function LinearMutator:CopyRaw()
		return self.mutations or false
	end

	M.Linear = LinearMutator.New
end

do -- table
	local HashedMutator = {}
	HashedMutator.__index = HashedMutator

	function HashedMutator.New()
		return setmetatable({
			mutations = false,
			mutations_list = false,
		}, HashedMutator)
	end

	function HashedMutator:Init()
		self.mutations = self.mutations or {}
		self.mutations_list = self.mutations_list or {}
	end

	function HashedMutator:InitBucket(hash, scope, key)
		self:Init()

		if not self.mutations[hash] then
			self.mutations[hash] = {}
			table_insert(self.mutations_list, self.mutations[hash])
		end

		return self.mutations[hash]
	end

	function HashedMutator:Track(entry)
		local hash = entry.hash
		self:InitBucket(hash, entry.scope, entry.key)
		local bucket = self.mutations[hash]

		if #bucket > entry.limit then
			return false, error_messages.too_many_mutations()
		end

		table_insert(
			bucket,
			{
				scope = entry.scope,
				value = entry.value,
				from_tracking = entry.from_tracking,
				key = entry.key,
			}
		)
		return true
	end

	function HashedMutator:Resolve(hash, scope, obj)
		return M.SolveMutations(self.mutations[hash], scope, obj)
	end

	function HashedMutator:Clear()
		self.mutations = false
		self.mutations_list = false
	end

	function HashedMutator:HasMutations()
		return self.mutations ~= false
	end

	function HashedMutator:ClearTracked()
		if not self:HasMutations() then return end

		for _, bucket in ipairs(self.mutations_list) do
			for i = #bucket, 1, -1 do
				if bucket[i].from_tracking then table_remove(bucket, i) end
			end
		end
	end

	function HashedMutator:Get()
		return self.mutations
	end

	function HashedMutator:Set(tbl)
		self.mutations = tbl
	end

	function HashedMutator:GetList()
		return self.mutations_list
	end

	function HashedMutator:CopyRaw()
		return self.mutations or false
	end

	M.Hashed = HashedMutator.New
end

return M
