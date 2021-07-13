local print = print
local tostring = tostring
local ipairs = ipairs
local table = require("table")
local Union = require("nattlua.types.union").Union
local setmetatable = _G.setmetatable
local META = {}
META.__index = META
local DEBUG = false

local function dprint(mut, reason)
	if not DEBUG then return end
	print(
		"\t" .. tostring(mut.scope) .. " - " .. tostring(mut.value) .. ": " .. reason
	)
end

local function copy(tbl)
	local copy = {}

	for i, val in ipairs(tbl) do
		copy[i] = val
	end

	return copy
end

local FindInType

do
	local function cmp(a, b, context, source)
		if not context[a] then
			context[a] = {}
			context[a][b] = FindInType(a, b, context, source)
		end

		return context[a][b]
	end

	-- this function is a sympton of me not knowing exactly how to find types in other types
	-- ideally this should be much more general and less complex
	-- i consider this a hack that should be refactored out

	function FindInType(a, b, context, source)
		source = source or b
		context = context or {}
		if not a then return false end
		if a == b then return source end

		if a:GetUpvalue() and b:GetUpvalue() then
			if a:GetUpvalueReference() or b:GetUpvalueReference() then return a:GetUpvalueReference() == b:GetUpvalueReference() and source or false end
			if a:GetUpvalue() == b:GetUpvalue() then return source end
		end

		if
			b:GetUpvalue() and
			a:GetTypeSourceRight() and
			a:GetTypeSourceRight():GetUpvalue() and
			a:GetTypeSourceRight():GetUpvalue().GetNode and
			a:GetTypeSourceRight():GetUpvalue():GetNode() == b:GetUpvalue():GetNode()
		then
			return cmp(a:GetTypeSourceRight(), b, context, source)
		end

		if a:GetUpvalue() and a:GetUpvalue().value then return cmp(a:GetUpvalue().value, b, context, a) end
		if a.type_checked then return cmp(a.type_checked, b, context, a) end
		if a:GetTypeSourceLeft() then return cmp(a:GetTypeSourceLeft(), b, context, a) end
		if a:GetTypeSourceRight() then return cmp(a:GetTypeSourceRight(), b, context, a) end
		if a:GetTypeSource() then return cmp(a:GetTypeSource(), b, context, a) end
		return false
	end
end

local function FindScopeFromTestCondition(root_scope, obj)
	local scope = root_scope
	local found_type

	while true do
		found_type = FindInType(scope:GetTestCondition(), obj)
		if found_type then break end
        
        -- find in siblings too, if they have returned
        -- ideally when cloning a scope, the new scope should be 
        -- inside of the returned scope, then we wouldn't need this code
        
        for _, child in ipairs(scope:GetChildren()) do
			if
				child ~= scope and
				(child:DidUncertainReturn() or root_scope:IsPartOfTestStatementAs(child))
			then
				local found_type = FindInType(child:GetTestCondition(), obj)

				if found_type then return child, found_type end
			end
		end

		scope = scope:GetParent()
		if not scope then return end
	end

	return scope, found_type
end

function META:GetValueFromScope(scope, obj, key, analyzer)
	local mutations = copy(self.mutations)

	if DEBUG then
		print("looking up mutations for " .. tostring(obj) .. "." .. tostring(key) .. ":")
	end

	do
		do
			local last_scope

			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if last_scope and mut.scope == last_scope then
					if DEBUG then
						dprint(mut, "redudant mutation")
					end

					table.remove(mutations, i)
				end

				last_scope = mut.scope
			end
		end

		for i = #mutations, 1, -1 do
			local mut = mutations[i]

			if scope:IsPartOfTestStatementAs(mut.scope) and scope ~= mut.scope then
				if DEBUG then
					dprint(mut, "not inside the same if statement")
				end

				table.remove(mutations, i)
			end
		end

		do
			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if mut.scope:IsPartOfIfStatement() and mut.scope:IsTestConditionInverted() then
					while true do
						local mut = mutations[i]
						if not mut then break end

						if not mut.scope:IsPartOfTestStatementAs(scope) and not mut.scope:Contains(scope) then
							for i = i, 1, -1 do
								if mutations[i].scope:Contains(scope) then
									if DEBUG then
										dprint(mut, "redudant mutation before else part of if statement")
									end

									table.remove(mutations, i)
								end
							end

							break
						end

						i = i - 1
					end

					break
				end
			end
		end

		do
			local test_scope_a = scope:FindFirstTestScope()

			if test_scope_a then
				local test_a = test_scope_a:GetTestCondition()

				for _, mut in ipairs(mutations) do
					if mut.scope ~= scope then
						local test_scope_b = mut.scope:FindFirstTestScope()

						if test_scope_b then
							if FindInType(test_a, test_scope_b:GetTestCondition()) then
								mut.certain_override = true

								if DEBUG then
									dprint(
										mut,
										"forcing scope certainty because this scope is using the same test condition"
									)
								end
							end
						end
					end
				end
			end
		end
	end

	local union = Union({})
	union:SetUpvalue(obj)

	if obj.Type == "table" then
		union:SetUpvalueReference("table-" .. key)
	else
		union:SetUpvalueReference(key)
	end

	for _, mut in ipairs(mutations) do
		local value = mut.value

		do
			local scope, scope_union = FindScopeFromTestCondition(mut.scope, value)

			if scope and mut.scope == scope then
				local test_scope = scope:FindFirstTestScope()

				if test_scope then
					local test = test_scope:GetTestCondition()

					if test.Type == "union" then
						local t

						if scope_union.Type == "union" then
							if test_scope:IsPartOfElseStatement() then
								t = scope_union:GetFalsyUnion()
							else
								t = scope_union:GetTruthyUnion()
							end
						else
							if test_scope:IsPartOfElseStatement() then
								t = test:GetFalsy()
							else
								t = test:GetTruthy()
							end
						end

						if t then
							union:RemoveType(t)
						end
					end
				end
			end
		end

		if mut.certain_override or mut.scope:IsCertain(scope) then
			union:Clear()
		end

		if _ == 1 and value.Type == "union" then
			union = value:Copy()
			union:SetUpvalue(obj)

			if obj.Type == "table" then
				union:SetUpvalueReference("table-" .. key)
			else
				union:SetUpvalueReference(key)
			end
		else
            -- check if we have to infer the function, otherwise adding it to the union can cause collisions
            if
				value.Type == "function" and
				not value.called and
				not value.explicit_return and
				union:HasType("function")
			then
				analyzer:Assert(value:GetNode() or analyzer.current_expression, analyzer:Call(value, value:GetArguments():Copy()))
			end

			union:AddType(value)
		end
	end

	local value = union

	if #union:GetData() == 1 then
		value = union:GetData()[1]
	end
	
	if value.Type == "union" then
		local found_scope, union = FindScopeFromTestCondition(scope, value)

		if found_scope then
			local current_scope = found_scope

			if #mutations > 1 then
				for i = #mutations, 1, -1 do
					if mutations[i].scope == current_scope then
						return value
					else
						break
					end
				end
			end

			local t

            -- the or part here refers to if *condition* then
            -- truthy/falsy _union is only created from binary operators and some others
            if
				found_scope:IsTestConditionInverted() or
				(found_scope ~= scope and scope:IsPartOfTestStatementAs(found_scope))
			then
				t = union:GetFalsyUnion() or value:GetFalsy()
			else
				t = union:GetTruthyUnion() or value:GetTruthy()
			end

			return t
		end
	end

	return value
end

function META:HasMutations()
	return self.mutations[1] ~= nil
end

function META:Mutate(value, scope)
	table.insert(self.mutations, {scope = scope, value = value,})
	return self
end

return function()
	return setmetatable({mutations = {}}, META)
end
