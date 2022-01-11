local ipairs = ipairs
local type = type
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Nil = require("nattlua.types.symbol").Nil
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local print = print
local tostring = tostring
local ipairs = ipairs
local table = require("table")
local Union = require("nattlua.types.union").Union
local setmetatable = _G.setmetatable
local DEBUG = false

local function dprint(mut, reason)
	print(
		"\t" .. tostring(mut.scope) .. " - " .. tostring(mut.value) .. ": " .. reason
	)
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
			b:GetUpvalue().GetNode and
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
			if child ~= scope and root_scope:IsPartOfTestStatementAs(child) then
				local found_type = FindInType(child:GetTestCondition(), obj)
				if found_type then return child, found_type end
			end
		end

		scope = scope:GetParent()
		if not scope then return end
	end

	return scope, found_type
end

local function get_value_from_scope(mutations, scope, obj, key, analyzer)
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
			
			if (scope:IsPartOfTestStatementAs(mut.scope) or (analyzer.current_if_statement and mut.scope.statement == analyzer.current_if_statement)) and scope ~= mut.scope then
				if DEBUG then
					dprint(mut, "not inside the same if statement")
				end

				table.remove(mutations, i)
			end
		end

		do
			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if mut.scope:GetStatementType() == "if" and mut.scope:IsPartOfElseStatement() then
					while true do
						local mut = mutations[i]
						if not mut then break end

						if not mut.scope:IsPartOfTestStatementAs(scope) and not mut.scope:IsCertain(scope) then
							for i = i, 1, -1 do
								if mutations[i].scope:IsCertain(scope) then
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
		union:SetUpvalueReference("table-" .. tostring(key))
	else
		union:SetUpvalueReference(key)
	end

	for _, mut in ipairs(mutations) do
		local value = mut.value

		do
			local upvalue_map = mut.scope:GetAffectedUpvaluesMap()

			if upvalue_map then
				for upvalue, stack in pairs(upvalue_map) do
					if upvalue.Type == "upvalue" then
						local val
						
						if mut.scope:IsPartOfElseStatement() or stack[#stack].inverted then
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
		if mut.certain_override or mut.scope:IsCertain(scope) then
			union:Clear()
		end

		if union:Get(value) and value.Type ~= "any" and mutations[1].value.Type ~= "union" and mutations[1].value.Type ~= "function" and mutations[1].value.Type ~= "any" then
			union:RemoveType(mutations[1].value)
		end
		
		if _ == 1 and value.Type == "union" then
			union = value:Copy()
			union:SetUpvalue(obj)

			if obj.Type == "table" then
				union:SetUpvalueReference("table-" .. tostring(key))
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
					if mutations[i].scope ~= current_scope then break end
					return value
				end
			end
			

			local upvalue_map = found_scope:GetAffectedUpvaluesMap()

            -- the or part here refers to if *condition* then
            -- truthy/falsy _union is only created from binary operators and some others
            if
				found_scope:IsPartOfElseStatement() or
				(found_scope ~= scope and scope:IsPartOfTestStatementAs(found_scope))
			then
				if upvalue_map and upvalue_map[obj] then
					return upvalue_map[obj][#upvalue_map[obj]].falsy
				end

				return union:GetFalsyUnion() or value:GetFalsy()
			else
				if upvalue_map and upvalue_map[obj] then
					local union = Union()

					for _, val in ipairs(upvalue_map[obj]) do						
						union:AddType(val.truthy)
					end

					return union
				end

				return union:GetTruthyUnion() or value:GetTruthy()
			end
		end
	end

	return value
end

local function initialize_mutation_tracker(obj, scope, key, hash, node)
	obj.mutations = obj.mutations or {}
	obj.mutations[hash] = obj.mutations[hash] or {}

	if obj.mutations[hash][1] == nil then
		if obj.Type == "table" then
			-- initialize the table mutations with an existing value or nil
			local val = (obj:GetContract() or obj):Get(key) or Nil():SetNode(node)
			
			table.insert(obj.mutations[hash], {scope = obj.scope or scope:GetRoot(), value = val})
		end
	end
end

local function copy(tbl)
	local copy = {}

	for i, val in ipairs(tbl) do
		copy[i] = val
	end

	return copy
end

return function(META)
	function META:GetMutatedValue(obj, key, value)
		if self:IsTypesystem() then return end

		local scope = self:GetScope()
		local node = key:GetNode()
		local hash = key:GetHash()
		
		if not hash then
			if key:GetUpvalue() then
				hash = key:GetUpvalue()
			end
		end

		if not hash then return value end

		initialize_mutation_tracker(obj, scope, key, hash, node)

		return get_value_from_scope(copy(obj.mutations[hash]), scope, obj, hash, self)
	end

	function META:MutateValue(obj, key, val, scope_override)
		if self:IsTypesystem() then return end

		local scope = scope_override or self:GetScope()
		local node = key:GetNode()
		local hash = key:GetHash()

		if not hash then
			if key:GetUpvalue() then
				hash = key:GetUpvalue()
			end
		end

		if not hash then return end -- no mutation?

		initialize_mutation_tracker(obj, scope, key, hash, node)

		if self:IsInUncertainLoop() then
			if val.dont_widen then
				val = val:Copy()
			else
				val = val:Copy():Widen()
			end
		end

		table.insert(obj.mutations[hash], {scope = scope, value = val})
	end

	function META:DumpUpvalueMutations(upvalue)
		print(upvalue)
		local hash = upvalue:GetKey()
		for i,v in ipairs(upvalue.mutations[hash]) do
			print(i, v.scope, v.value)
		end
	end

	function META:GetMutatedUpvalue(upvalue)
		if self:IsTypesystem() then return end
		local scope = self:GetScope()

		local hash = upvalue:GetKey()
		
		upvalue.mutations = upvalue.mutations or {}
		upvalue.mutations[hash] = upvalue.mutations[hash] or {}

		return get_value_from_scope(copy(upvalue.mutations[hash]), scope, upvalue, hash, self)
	end

	function META:MutateUpvalue(upvalue, val, scope_override)
		if self:IsTypesystem() then return end
		local scope = scope_override or self:GetScope()

		local hash = upvalue:GetKey()
        
		val:SetUpvalue(upvalue)
		val:SetUpvalueReference(hash)

		upvalue.mutations = upvalue.mutations or {}
		upvalue.mutations[hash] = upvalue.mutations[hash] or {}

		if self:IsInUncertainLoop() then
			if val.dont_widen then
				val = val:Copy()
			else
				val = val:Copy():Widen()
			end
		end

		table.insert(upvalue.mutations[hash], {scope = scope, value = val})
	end
end
