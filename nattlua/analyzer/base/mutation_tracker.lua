local print = print
local tostring = tostring
local ipairs = ipairs
local table = require("table")
local setmetatable = setmetatable
local types = require("nattlua.types.types")
local META = {}
META.__index = META
local DEBUG = false

local function dprint(mut, reason)
	if not DEBUG then return end
	print(
		"\t" .. tostring(mut.scope) .. " - " .. tostring(mut.value) .. ": " .. reason
	)
end

local function same_if_statement(a, b)
	return a.if_statement and a.if_statement == b.if_statement
end

local function copy(tbl)
	local copy = {}

	for i, val in ipairs(tbl) do
		copy[i] = val
	end

	return copy
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

			if same_if_statement(scope, mut.scope) and scope ~= mut.scope then
				if DEBUG then
					dprint(mut, "not inside the same if statement")
				end

				table.remove(mutations, i)
			end
		end

		do
			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if mut.scope.if_statement and mut.scope.test_condition_inverted then
					while true do
						local mut = mutations[i]
						if not mut then break end

						if not same_if_statement(mut.scope, scope) and not mut.scope:Contains(scope) then
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
			local test_a = scope:GetTestCondition()

			if test_a then
				for _, mut in ipairs(mutations) do
					if mut.scope ~= scope then
						local test_b = mut.scope:GetTestCondition()

						if test_b then
							if types.FindInType(test_a, test_b) then
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

	local union = types.Union({})
	union:SetUpvalue(obj, key)

	for _, mut in ipairs(mutations) do
		local value = mut.value

		do
			local scope, scope_union = mut.scope:FindScopeFromTestCondition(value)

			if scope and mut.scope == scope then
				local test, inverted = scope:GetTestCondition()

				if test.Type == "union" then
					local t

					if inverted then
						t = scope_union.falsy_union or test:GetFalsy()
					else
						t = scope_union.truthy_union or test:GetTruthy()
					end

					if t then
						union:RemoveType(t)
					end
				end
			end
		end

		if mut.certain_override or mut.scope:IsCertain(scope) then
			union:Clear()
		end

		if _ == 1 and value.Type == "union" then
			union = value:Copy()
			union:SetUpvalue(obj, key)
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
		local found_scope, union = scope:FindScopeFromTestCondition(value)

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
				found_scope.test_condition_inverted or
				(found_scope ~= scope and same_if_statement(scope, found_scope))
			then
				t = union.falsy_union or value:GetFalsy()
			else
				t = union.truthy_union or value:GetTruthy()
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