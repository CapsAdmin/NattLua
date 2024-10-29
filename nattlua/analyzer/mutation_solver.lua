local ipairs = ipairs
local table = _G.table
local table_remove = _G.table.remove
local Union = require("nattlua.types.union").Union
local shallow_copy = require("nattlua.other.shallow_copy")

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

local function remove_redundant_mutations(mutations, scope, obj)
	if #mutations <= 1 then return mutations end

	-- First pass: Filter out sibling scope mutations and contained scopes
	local result = {}

	for i = 1, #mutations do
		local mut = mutations[i]

		if not is_part_of_sibling_scope(mut, scope) then
			local should_keep = true

			-- Check if this mutation is contained in later mutations' scopes
			for j = i + 1, #mutations do
				if mutations[j].scope:Contains(mut.scope) then
					should_keep = false

					break
				end
			end

			if should_keep then table.insert(result, mut) end
		end
	end

	if #result == 0 then return end

	local temp = {}

	-- Handle else conditional cases
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

	if #result == 0 then return end

	-- Final pass: Check for certain overrides
	local test_scope_a = scope:FindFirstConditionalScope()

	if test_scope_a then
		for i = #result, 1, -1 do
			local mut = result[i]

			if
				certain_override(mut, scope, obj, test_scope_a) or
				mut.scope:IsCertainFromScope(scope)
			then
				local new = {}
				local new_i = 1

				for i = i, #result do
					new[new_i] = result[i]
					new_i = new_i + 1
				end

				return new
			end
		end
	end

	return result
end

local function get_value(mut)
	if mut.value.Type == "union" and #mut.value:GetData() == 1 then
		return mut.value:GetData()[1]
	end

	return mut.value
end

local function mutation_solver(mutations, scope, obj)
	-- common case early exit, if the last mutation was done in the same scope
	if mutations[#mutations] and mutations[#mutations].scope == scope then
		local first = get_value(mutations[#mutations])
		local union

		if first.Type == "union" then
			union = first:Copy()
		else
			union = Union({first})
		end

		if obj.Type == "upvalue" then union:SetUpvalue(obj) end

		return union:Simplify()
	end

	local mutations = remove_redundant_mutations(mutations, scope, obj)

	if not mutations then return end

	local union
	local start = 1
	local first = get_value(mutations[1])

	if first.Type == "union" then
		union = first:Copy()
		start = 2
	else
		union = Union()
	end

	for i = start, #mutations do
		local mut = mutations[i]
		local value = get_value(mut)

		if i > 1 then
			if obj.Type == "upvalue" then -- upvalue
				if mut.scope:GetStatementType() == "if" then
					local data = mut.scope:FindTrackedUpvalue(obj)

					if data and data.stack then
						local val

						if mut.scope:IsElseConditionalScope() then
							val = data.stack[#data.stack].falsy
						else
							val = data.stack[#data.stack].truthy
						end

						if val and (val.Type ~= "union" or not val:IsEmpty()) then
							union:RemoveType(val)
						end
					end
				end
			elseif -- table
				value.Type ~= "any" and
				mutations[1].value.Type ~= "union" and
				mutations[1].value.Type ~= "function" and
				mutations[1].value.Type ~= "any" and
				union:HasTypeObject(value)
			then
				union:RemoveType(mutations[1].value)
			end
		end

		union:AddType(value)
	end

	if obj.Type == "upvalue" then union:SetUpvalue(obj) end

	return union:Simplify()
end

return mutation_solver
