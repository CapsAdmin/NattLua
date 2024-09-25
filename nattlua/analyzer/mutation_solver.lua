local ipairs = ipairs
local table = _G.table
local table_remove = _G.table.remove
local Union = require("nattlua.types.union").Union

local function mutation_solver(mutations, scope, obj)
	do
		--[[
			remove previous mutations that are in the same scope

			x = val -- remove
			x = val -- remove
			x = val -- remove
			do
				x = val -- remove
				x = val -- keep
			end
			x = val -- keep
		]] for i = #mutations, 1, -1 do
			local mut_a = mutations[i]

			if mut_a then
				for j = i - 1, 1, -1 do
					local mut_b = mutations[j]

					if not mut_a.scope:Contains(mut_b.scope) then break end

					table_remove(mutations, j)
				end
			end
		end

		for i = #mutations, 1, -1 do
			local mut_a = mutations[i]

			if
				scope ~= mut_a.scope and
				(
					--[[
						-- remove mutations that occur in a sibling scope of an if statement
						local x = val
						if y then
							x = val
							-- if x is resolved here we remove the below mutation
						else
							x = val
							-- if x is resolved here, we remove the above mutation
						end
					]] scope:BelongsToIfStatement(mut_a.scope) or
					(
						-- we do the same for tracked if statements scopes
						--[[
							if foo.bar then
								-- here foo.bar is tracked to be at least truthy
							else
								-- here foo.bar is tracked to be at least falsy
							end
						]] mut_a.from_tracking and
						not mut_a.scope:Contains(scope)
					)
				)
			then
				table_remove(mutations, i)
			end
		end

		for i = #mutations, 1, -1 do
			local mut = mutations[i]

			if mut.scope:IsElseConditionalScope() then
				for i = i - 1, 1, -1 do
					local mut = mutations[i]

					if
						not mut.scope:BelongsToIfStatement(scope) and
						not mut.scope:IsCertainFromScope(scope)
					then
						for i = i, 1, -1 do
							if mutations[i].scope:IsCertainFromScope(scope) then
								-- redudant mutation before else part of if statement
								table_remove(mutations, i)
							end
						end

						break
					end
				end

				break
			end
		end
	end

	if not mutations[1] then return end

	do
		local test_scope_a = scope:FindFirstConditionalScope()

		if test_scope_a then
			for _, mut in ipairs(mutations) do
				if mut.scope ~= scope then
					local test_scope_b = mut.scope:FindFirstConditionalScope()

					if test_scope_b and test_scope_b ~= test_scope_a and obj.Type ~= "table" then
						if test_scope_a:TracksSameAs(test_scope_b, obj) then
							-- forcing scope certainty because this scope is using the same test condition
							mut.certain_override = true
						end
					end
				end
			end
		end
	end

	local union = Union()

	if obj.Type == "upvalue" then union:SetUpvalue(obj) end

	for _, mut in ipairs(mutations) do
		local value = mut.value

		if value.Type == "union" and #value:GetData() == 1 then
			value = value:GetData()[1]
		end

		do
			local upvalues = mut.scope:GetTrackedUpvalues()

			if upvalues then
				for _, data in ipairs(upvalues) do
					local stack = data.stack

					if stack then
						local val

						if mut.scope:IsElseConditionalScope() then
							val = stack[#stack].falsy
						else
							val = stack[#stack].truthy
						end

						if val and (val.Type ~= "union" or not val:IsEmpty()) then
							union:RemoveType(val)
						end
					end
				end
			end
		end

		-- IsCertain isn't really accurate and seems to be used as a last resort in case the above logic doesn't work
		if mut.certain_override or mut.scope:IsCertainFromScope(scope) then
			union:Clear()
		end

		if
			union:Get(value) and
			value.Type ~= "any" and
			mutations[1].value.Type ~= "union" and
			mutations[1].value.Type ~= "function" and
			mutations[1].value.Type ~= "any"
		then
			union:RemoveType(mutations[1].value)
		end

		if _ == 1 and value.Type == "union" then
			union = value:Copy()

			if obj.Type == "upvalue" then union:SetUpvalue(obj) end
		else
			union:AddType(value)
		end
	end

	local value = union

	if #union:GetData() == 1 then
		value = union:GetData()[1]

		if obj.Type == "upvalue" then value:SetUpvalue(obj) end

		return value
	end

	local found_scope, data = scope:FindResponsibleConditionalScopeFromUpvalue(obj)

	if not found_scope or not data.stack then return value end

	local stack = data.stack

	if
		found_scope:IsElseConditionalScope() or
		(
			found_scope ~= scope and
			scope:BelongsToIfStatement(found_scope)
		)
	then
		local union = stack[#stack].falsy

		if union:GetCardinality() == 0 then
			union = Union()

			for _, val in ipairs(stack) do
				union:AddType(val.falsy)
			end
		end

		if obj.Type == "upvalue" then union:SetUpvalue(obj) end

		return union
	end

	local union = Union()

	for _, val in ipairs(stack) do
		union:AddType(val.truthy)
	end

	if obj.Type == "upvalue" then union:SetUpvalue(obj) end

	return union
end

return mutation_solver
