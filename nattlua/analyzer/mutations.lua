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

local function get_value_from_scope(self, mutations, scope, obj, key)
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

		
			if 
				(
					scope:IsPartOfTestStatementAs(mut.scope) or 
					(self.current_if_statement and mut.scope.statement == self.current_if_statement) or
					(mut.from_tracking and not mut.scope:IsCertain(scope))
				)
				and scope ~= mut.scope 
			then
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
				for _, mut in ipairs(mutations) do
					if mut.scope ~= scope then
						local test_scope_b = mut.scope:FindFirstTestScope()

						if test_scope_b then
							if test_scope_a:TracksSameAs(test_scope_b) then
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
	if obj.Type == "upvalue" then
		union:SetUpvalue(obj)
	end

	if obj.Type == "table" then
		union:SetUpvalueReference("table-" .. tostring(key))
	else
		union:SetUpvalueReference(key)
	end

	for _, mut in ipairs(mutations) do
		local value = mut.value

		if value.Type == "union" and #value:GetData() == 1 then
			value = value:GetData()[1]
		end

		do
			local upvalues = mut.scope:GetTrackedObjects()

			if upvalues then
				for _, data in pairs(upvalues) do
					local stack = data.stack
					local val
					
					if mut.scope:IsPartOfElseStatement() then
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
	
		-- IsCertain isn't really accurate and seems to be used as a last resort in case the above logic doesn't work
		if mut.certain_override or mut.scope:IsCertain(scope) then
			union:Clear()
		end

		if union:Get(value) and value.Type ~= "any" and mutations[1].value.Type ~= "union" and mutations[1].value.Type ~= "function" and mutations[1].value.Type ~= "any" then
			union:RemoveType(mutations[1].value)
		end
		
		if _ == 1 and value.Type == "union" then
			union = value:Copy()
			if obj.Type == "upvalue" then
				union:SetUpvalue(obj)
			end

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
				self:Assert(value:GetNode() or self.current_expression, self:Call(value, value:GetArguments():Copy()))
			end

			union:AddType(value)
		end
	end

	local value = union

	if #union:GetData() == 1 then
		value = union:GetData()[1]
		if obj.Type == "upvalue" then
			value:SetUpvalue(obj)
		end
	end
	if value.Type == "union" then
		local found_scope = FindScopeFromTestCondition(scope, value)
		if found_scope then
			local upvalues = found_scope:GetTrackedObjects()
			if upvalues then
				for _, data in ipairs(upvalues) do
					if data.upvalue == obj then
						local stack = data.stack
						if
							found_scope:IsPartOfElseStatement() or
							(found_scope ~= scope and scope:IsPartOfTestStatementAs(found_scope))
						then
							return stack[#stack].falsy
						else
							local union = Union()

							for _, val in ipairs(stack) do
								union:AddType(val.truthy)
							end

							return union
						end
						break
					end
				end
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

		return get_value_from_scope(self, copy(obj.mutations[hash]), scope, obj, hash)
	end

	function META:MutateValue(obj, key, val, scope_override, from_tracking)
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

		table.insert(obj.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking})
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

		return get_value_from_scope(self, copy(upvalue.mutations[hash]), scope, upvalue, hash)
	end

	function META:MutateUpvalue(upvalue, val, scope_override, from_tracking)
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

		table.insert(upvalue.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking})
	end


	do

		function META:PushTruthyExpressionContext()
			self.truthy_expression_context = (self.truthy_expression_context or 0) + 1
		end

		function META:PopTruthyExpressionContext()
			self.truthy_expression_context = self.truthy_expression_context - 1
		end

		function META:IsTruthyExpressionContext()
			return self.truthy_expression_context and self.truthy_expression_context > 0 and true or false
		end

		function META:PushFalsyExpressionContext()
			self.falsy_expression_context = (self.falsy_expression_context or 0) + 1
		end

		function META:PopFalsyExpressionContext()
			self.falsy_expression_context = self.falsy_expression_context - 1
		end

		function META:IsFalsyExpressionContext()
			return self.falsy_expression_context and self.falsy_expression_context > 0 and true or false
		end
	end

	do

		function META:ClearTrackedObjects()
			if self.tracked_upvalues then
				for _, upvalue in ipairs(self.tracked_upvalues) do
					upvalue.tracked_stack = nil
				end
				self.tracked_upvalues_done = nil
				self.tracked_upvalues = nil
			end

			if self.tracked_tables then
				for _, tbl in ipairs(self.tracked_tables) do
					tbl.tracked_stack = nil
				end
				self.tracked_tables_done = nil
				self.tracked_tables = nil
			end
		end

		function META:TrackUpvalue(obj, truthy_union, falsy_union, inverted)
			if self:IsTypesystem() then return end
			if obj.Type ~= "union" then return end
			local upvalue = obj:GetUpvalue()
			
			if not upvalue then return end

			truthy_union = truthy_union or obj:GetTruthy()
			falsy_union = falsy_union or obj:GetFalsy()

			upvalue.tracked_stack = upvalue.tracked_stack or {}
			table.insert(upvalue.tracked_stack, {truthy = truthy_union, falsy = falsy_union, inverted = inverted})
			
			self.tracked_upvalues = self.tracked_upvalues or {}
			self.tracked_upvalues_done = self.tracked_upvalues_done or {}
			if not self.tracked_upvalues_done[upvalue] then
				table.insert(self.tracked_upvalues, upvalue)
				self.tracked_upvalues_done[upvalue] = true
			end
		end

		function META:GetTrackedUpvalue(obj)
			if self:IsTypesystem() then return end
			local upvalue = obj:GetUpvalue()
			local stack = upvalue and upvalue.tracked_stack

			if not stack then return end
			
			if self:IsTruthyExpressionContext() then
				return stack[#stack].truthy:SetUpvalue(upvalue)
			elseif self:IsFalsyExpressionContext() then
				return stack[#stack].falsy:SetUpvalue(upvalue)
			end
		end

		function META:TrackTableIndex(obj, key, val)
			if self:IsTypesystem() then return end
			if not val or val.Type ~= "union" then return end
			local hash = key:GetHash()
			if not hash then return end
			
			val.parent_table = obj
			val.parent_key = key
			
			local truthy_union = val:GetTruthy()
			local falsy_union = val:GetFalsy()

			falsy_union.parent_table = obj
			falsy_union.parent_key = key
			truthy_union.parent_table = obj
			truthy_union.parent_key = key

			obj.tracked_stack = obj.tracked_stack or {}
			obj.tracked_stack[hash] = obj.tracked_stack[hash] or {}

			table.insert(obj.tracked_stack[hash], {
				key = key, 
				truthy = truthy_union, 
				falsy = falsy_union, 
				inverted = self.inverted_index_tracking, 
				truthy_falsy = true
			})

			self.tracked_tables = self.tracked_tables or {}
			self.tracked_tables_done = self.tracked_tables_done or {}
			if not self.tracked_tables_done[obj] then
				table.insert(self.tracked_tables, obj)
				self.tracked_tables_done[obj] = true
			end
		end

		function META:TrackTableIndexUnion(obj, key, truthy_union, falsy_union, inverted)
			if self:IsTypesystem() then return end
			local hash = key:GetHash()
			if not hash then return end
			
			obj.tracked_stack = obj.tracked_stack or {}
			obj.tracked_stack[hash] = obj.tracked_stack[hash] or {}

			falsy_union.parent_table = obj
			falsy_union.parent_key = key
			truthy_union.parent_table = obj
			truthy_union.parent_key = key

			for i = #obj.tracked_stack[hash], 1, -1 do
				local tracked = obj.tracked_stack[hash][i]
				if tracked.truthy_falsy then
					table.remove(obj.tracked_stack[hash], i)
				end
			end

			table.insert(obj.tracked_stack[hash], {
				key = key, 
				truthy = truthy_union, 
				falsy = falsy_union, 
				inverted = inverted
			})

			self.tracked_tables = self.tracked_tables or {}
			table.insert(self.tracked_tables, obj)
		end

		function META:GetTrackedObjectWithKey(obj, key)
			if not obj.tracked_stack or obj.tracked_stack[1] then return end
			local hash = key:GetHash()
			if not hash then return end
			local stack = obj.tracked_stack[hash]

			if not stack then return end

			if self:IsTruthyExpressionContext() then
				return stack[#stack].truthy
			elseif self:IsFalsyExpressionContext() then
				return stack[#stack].falsy
			end
		end


		function META:GetTrackedObjectMap(old_upvalues)
			local upvalues = {}
			local tables = {}

			local translate = {}
			if old_upvalues then
				for i, upvalue in ipairs(self:GetScope().upvalues.runtime.list) do
					local old = old_upvalues[i]
					translate[old] = upvalue
					upvalue.tracked_stack = old.tracked_stack
				end
			end

			if self.tracked_upvalues then
				for _, upvalue in ipairs(self.tracked_upvalues) do
					local stack = upvalue.tracked_stack

					if old_upvalues then
						upvalue = translate[upvalue]
					end

					if stack then
						table.insert(upvalues, {
							upvalue = upvalue, 
							stack = copy(stack)
						})
					end
				end
			end

			if self.tracked_tables then
				for _, tbl in ipairs(self.tracked_tables) do
					if tbl.tracked_stack and not tbl.tracked_stack[1] then
						for _, stack in pairs(tbl.tracked_stack) do
							table.insert(tables, {
								obj = tbl, 
								key = stack[#stack].key, 
								stack = copy(stack),
							})
						end
					end
				end
			end

			return upvalues, tables
		end

		function META:MutateTrackedFromIf(upvalues, tables)
			if upvalues then
				for _, data in ipairs(upvalues) do
					local union = Union()
					for _, v in ipairs(data.stack) do
						union:AddType(v.truthy)
					end
					self:MutateUpvalue(data.upvalue, union, nil, true)
				end
			end

			if tables then
				for _, data in ipairs(tables) do
					local union = Union()
					for _, v in ipairs(data.stack) do
						union:AddType(v.truthy)
					end
					self:MutateValue(data.obj, data.key, union, nil, true)
				end
			end
		end

		function META:MutateTrackedFromIfElse(blocks)
			for i, block in ipairs(blocks) do
				if block.upvalues then
					for _, data in ipairs(block.upvalues) do
						local union = self:GetMutatedUpvalue(data.upvalue)
						if union.Type == "union" then
							for _, v in ipairs(data.stack) do
								union:RemoveType(v.truthy)
							end
						end
						self:MutateUpvalue(data.upvalue, union, nil, true)
					end
				end

				if block.tables then
					for _, data in ipairs(block.tables) do
						local union = self:GetMutatedValue(data.obj, data.key)
						if union.Type == "union" then
							for _, v in ipairs(data.stack) do
								union:RemoveType(v.truthy)
							end
						end
						self:MutateValue(data.obj, data.key, union, nil, true)
					end
				end
			end
			
		end

		function META:MutateTrackedFromReturn(scope, scope_override, negate, upvalues, tables)
			if upvalues then
				for _, data in ipairs(upvalues) do
					local stack = data.stack
					local val
					if scope:IsPartOfElseStatement() or stack[#stack].inverted then
						val = negate and stack[#stack].truthy or stack[#stack].falsy
					else
						val = negate and stack[#stack].falsy or stack[#stack].truthy
					end

					if val and (val.Type ~= "union" or not val:IsEmpty()) then
						if #val:GetData() == 1 then
							val = val:GetData()[1]
						end

						self:MutateUpvalue(data.upvalue, val, scope_override)
					end
				end
			end

			if tables then
				for _, data in ipairs(tables) do
					local stack = data.stack
					local val
					if scope:IsPartOfElseStatement() or stack[#stack].inverted then
						val = negate and stack[#stack].truthy or stack[#stack].falsy
					else
						val = negate and stack[#stack].falsy or stack[#stack].truthy
					end

					if val and (val.Type ~= "union" or not val:IsEmpty()) then
						if #val:GetData() == 1 then
							val = val:GetData()[1]
						end	 
		
						self:MutateValue(data.obj, data.key, val, scope_override)
					end
				end
			end
		end
	end
end
