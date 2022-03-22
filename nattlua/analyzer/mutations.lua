local ipairs = ipairs
local Nil = require("nattlua.types.symbol").Nil
local Table = require("nattlua.types.table").Table
local print = print
local tostring = tostring
local ipairs = ipairs
local table = _G.table
local Union = require("nattlua.types.union").Union

local function get_value_from_scope(self, mutations, scope, obj, key)
	do
		do
			local last_scope

			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if last_scope and mut.scope == last_scope then
					-- "redudant mutation"
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
					(
						self.current_if_statement and
						mut.scope.statement == self.current_if_statement
					)
					or
					(
						mut.from_tracking and
						not mut.scope:IsCertainFromScope(scope)
					)
					or
					(
						obj.Type == "table" and
						obj:GetContract() ~= mut.contract
					)
				)
				and
				scope ~= mut.scope
			then
				-- not inside the same if statement"
				table.remove(mutations, i)
			end
		end

		do
			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if mut.scope:IsElseConditionalScope() then
					while true do
						local mut = mutations[i]

						if not mut then break end

						if
							not mut.scope:IsPartOfTestStatementAs(scope) and
							not mut.scope:IsCertainFromScope(scope)
						then
							for i = i, 1, -1 do
								if mutations[i].scope:IsCertainFromScope(scope) then
									-- redudant mutation before else part of if statement
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
			local test_scope_a = scope:FindFirstConditionalScope()

			if test_scope_a then
				for _, mut in ipairs(mutations) do
					if mut.scope ~= scope then
						local test_scope_b = mut.scope:FindFirstConditionalScope()

						if test_scope_b then
							if test_scope_a:TracksSameAs(test_scope_b) then
								-- forcing scope certainty because this scope is using the same test condition
								mut.certain_override = true
							end
						end
					end
				end
			end
		end
	end

	if not mutations[1] then return end

	local union = Union({})

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

		if obj.Type == "upvalue" then value:SetUpvalue(obj) end
	end
    
	if value.Type == "union" then
		local found_scope, data = scope:FindResponsibleConditionalScopeFromUpvalue(obj)    

        if found_scope then
			local stack = data.stack

			if stack then
				if
					found_scope:IsElseConditionalScope() or
					(
						found_scope ~= scope and
						scope:IsPartOfTestStatementAs(found_scope)
					)
				then
					local union = stack[#stack].falsy


                    if union:GetLength() == 0 then
                        union = Union()

                        for _, val in ipairs(stack) do
                            union:AddType(val.falsy)
                        end
                    end

					if obj.Type == "upvalue" then union:SetUpvalue(obj) end

					return union
				else
					local union = Union()

					for _, val in ipairs(stack) do
						union:AddType(val.truthy)
					end

					if obj.Type == "upvalue" then union:SetUpvalue(obj) end

					return union
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
			table.insert(
				obj.mutations[hash],
				{scope = obj.scope or scope:GetRoot(), value = val, contract = obj:GetContract()}
			)
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
	function META:GetMutatedTableLength(obj)
		local mutations = obj.mutations

		if not mutations then return obj:GetLength() end

		local temp = Table()

		for key in pairs(mutations) do
			local realkey

			for _, kv in ipairs(obj:GetData()) do
				if kv.key:GetHash() == key then
					realkey = kv.key

					break
				end
			end

			local val = self:GetMutatedTableValue(obj, realkey, obj:Get(realkey))
			temp:Set(realkey, val)
		end

		return temp:GetLength()
	end

	function META:GetMutatedTableValue(tbl, key, value)
		if self:IsTypesystem() then return value end

		local hash = key:GetHash() or key:GetUpvalue() and key:GetUpvalue()

		if not hash then return end

		local scope = self:GetScope()
		local node = key:GetNode()
		initialize_mutation_tracker(tbl, scope, key, hash, node)
		return get_value_from_scope(self, copy(tbl.mutations[hash]), scope, tbl, hash)
	end

	function META:MutateTable(tbl, key, val, scope_override, from_tracking)
		if self:IsTypesystem() then return end

		local hash = key:GetHash() or key:GetUpvalue() and key:GetUpvalue()

		if not hash then return end

		local scope = scope_override or self:GetScope()
		local node = key:GetNode()
		initialize_mutation_tracker(tbl, scope, key, hash, node)

		if self:IsInUncertainLoop(scope) then
			if val.dont_widen then
				val = val:Copy()
			else
				val = val:Copy():Widen()
			end
		end

		table.insert(tbl.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking})

		if from_tracking then scope:AddTrackedObject(tbl) end
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
		upvalue.mutations = upvalue.mutations or {}
		upvalue.mutations[hash] = upvalue.mutations[hash] or {}

		if self:IsInUncertainLoop(scope) then
			if val.dont_widen then
				val = val:Copy()
			else
				val = val:Copy():Widen()
			end
		end

		table.insert(upvalue.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking})

		if from_tracking then scope:AddTrackedObject(upvalue) end
	end

	do
        function META:PushRefCall()
            self:PushContextRef("ref_call")
        end

        function META:PopRefCall()
            self:PopContextRef("ref_call")
        end
        
        function META:IsRefCall()
            return self:GetContextRef("ref_call")
        end

        function META:PushDisableExpressionContext(b)
            self:PushContextValue("disable_expression_context", b)
        end

        function META:PopDisableExpressionContext()
            self:PopContextValue("disable_expression_context")
        end

		function META:PushTruthyExpressionContext()
			self:PushContextRef("truthy_expression_context")
		end

		function META:PopTruthyExpressionContext()
			self:PopContextRef("truthy_expression_context")
		end

		function META:IsTruthyExpressionContext()
            if self:GetContextValue("disable_expression_context") == true then return false end
			return self:GetContextRef("truthy_expression_context")
		end

		function META:PushFalsyExpressionContext()
			self:PushContextRef("falsy_expression_context")
		end

		function META:PopFalsyExpressionContext()
			self:PopContextRef("falsy_expression_context")
		end

		function META:IsFalsyExpressionContext()
            if self:GetContextValue("disable_expression_context") == true then return false end
			return self:GetContextRef("falsy_expression_context")
		end
	end

	do
		function META:ClearTracked()
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

			local upvalue = obj:GetUpvalue()

			if not upvalue then return end

			if obj.Type == "union" then
				if not truthy_union then truthy_union = obj:GetTruthy() end

				if not falsy_union then falsy_union = obj:GetFalsy() end

				upvalue.tracked_stack = upvalue.tracked_stack or {}
				table.insert(
					upvalue.tracked_stack,
					{
						truthy = truthy_union,
						falsy = falsy_union,
						inverted = inverted,
					}
				)
			end

			self.tracked_upvalues = self.tracked_upvalues or {}
			self.tracked_upvalues_done = self.tracked_upvalues_done or {}

			if not self.tracked_upvalues_done[upvalue] then
				table.insert(self.tracked_upvalues, upvalue)
				self.tracked_upvalues_done[upvalue] = true
			end
		end

		function META:TrackUpvalueNonUnion(obj)
			if self:IsTypesystem() then return end

			local upvalue = obj:GetUpvalue()

			if not upvalue then return end

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

			local hash = key:GetHash()

			if not hash then return end

			val.parent_table = obj
			val.parent_key = key
			local truthy_union = val:GetTruthy()
			local falsy_union = val:GetFalsy()
			self:TrackTableIndexUnion(obj, key, truthy_union, falsy_union, self.inverted_index_tracking, true)
		end

		function META:TrackTableIndexUnion(obj, key, truthy_union, falsy_union, inverted, truthy_falsy)
			if self:IsTypesystem() then return end

			local hash = key:GetHash()

			if not hash then return end

			obj.tracked_stack = obj.tracked_stack or {}
			obj.tracked_stack[hash] = obj.tracked_stack[hash] or {}

			if falsy_union then
				falsy_union.parent_table = obj
				falsy_union.parent_key = key
			end

			if truthy_union then
				truthy_union.parent_table = obj
				truthy_union.parent_key = key
			end

			for i = #obj.tracked_stack[hash], 1, -1 do
				local tracked = obj.tracked_stack[hash][i]

				if tracked.truthy_falsy then
					table.remove(obj.tracked_stack[hash], i)
				end
			end

			table.insert(
				obj.tracked_stack[hash],
				{
					contract = obj:GetContract(),
					key = key,
					truthy = truthy_union,
					falsy = falsy_union,
					inverted = inverted,
					truthy_falsy = truthy_falsy,
				}
			)
			self.tracked_tables = self.tracked_tables or {}
			self.tracked_tables_done = self.tracked_tables_done or {}

			if not self.tracked_tables_done[obj] then
				table.insert(self.tracked_tables, obj)
				self.tracked_tables_done[obj] = true
			end
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

		function META:GetTrackedTables()
			local tables = {}

			if self.tracked_tables then
				for _, tbl in ipairs(self.tracked_tables) do
					if tbl.tracked_stack then
						for _, stack in pairs(tbl.tracked_stack) do
							table.insert(
								tables,
								{
									obj = tbl,
									key = stack[#stack].key,
									stack = copy(stack),
								}
							)
						end
					end
				end
			end

			return tables
		end

		function META:GetTrackedUpvalues(old_upvalues)
			local upvalues = {}
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

					if old_upvalues then upvalue = translate[upvalue] end

					table.insert(upvalues, {upvalue = upvalue, stack = stack and copy(stack)})
				end
			end

			return upvalues
		end

		--[[
			local x: 1 | 2 | 3

			if x == 1 then
				assert(x == 1)
			end
		]] function META:ApplyMutationsInIf(upvalues, tables)
			if upvalues then
				for _, data in ipairs(upvalues) do
					if data.stack then
						local union = Union()

						for _, v in ipairs(data.stack) do
							if v.truthy then union:AddType(v.truthy) end
						end

						if not union:IsEmpty() then
							union:SetUpvalue(data.upvalue)
							self:MutateUpvalue(data.upvalue, union, nil, true)
						end
					end
				end
			end

			if tables then
				for _, data in ipairs(tables) do
					local union = Union()

					for _, v in ipairs(data.stack) do
						if v.truthy then union:AddType(v.truthy) end
					end

					if not union:IsEmpty() then
						self:MutateTable(data.obj, data.key, union, nil, true)
					end
				end
			end
		end

		--[[
			local x: 1 | 2 | 3

			if x == 1 then
			else
				-- we get the original value and remove the truthy values (x == 1) and end up with 2 | 3
				assert(x == 2 | 3)
			end
		]] function META:ApplyMutationsInIfElse(blocks)
			for i, block in ipairs(blocks) do
				if block.upvalues then
					for _, data in ipairs(block.upvalues) do
						if data.stack then
							local union = self:GetMutatedUpvalue(data.upvalue)
							if union.Type == "union" then
								for _, v in ipairs(data.stack) do
									union:RemoveType(v.truthy)
								end

								union:SetUpvalue(data.upvalue)
							end

							self:MutateUpvalue(data.upvalue, union, nil, true)
						end
					end
				end

				if block.tables then
					for _, data in ipairs(block.tables) do
						local union = self:GetMutatedTableValue(data.obj, data.key)

						if union then
							if union.Type == "union" then
								for _, v in ipairs(data.stack) do
									union:RemoveType(v.truthy)
								end
							end

							self:MutateTable(data.obj, data.key, union, nil, true)
						end
					end
				end
			end
		end

		--[[
			local x: 1 | 2 | 3

			if x == 1 then return end

			assert(x == 2 | 3)
		]] --[[
			local x: 1 | 2 | 3

			if x == 1 then else return end

			assert(x == 1)
		]] --[[
			local x: 1 | 2 | 3

			if x == 1 then error("!") end

			assert(x == 2 | 3)
		]] local function solve(data, scope, negate)
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

		function META:ApplyMutationsAfterReturn(scope, scope_override, negate, upvalues, tables)
			if upvalues then
				for _, data in ipairs(upvalues) do
					local val = solve(data, scope, negate)

					if val then
						val:SetUpvalue(data.upvalue)
						self:MutateUpvalue(data.upvalue, val, scope_override, true)
					end
				end
			end

			if tables then
				for _, data in ipairs(tables) do
					local val = solve(data, scope, negate)

					if val then
						self:MutateTable(data.obj, data.key, val, scope_override, true)
					end
				end
			end
		end
	end
end
