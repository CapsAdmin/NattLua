local ipairs = _G.ipairs
local LNumber = require("nattlua.types.number").LNumber
local ConstraintStore = require("nattlua.analyzer.constraint_store")
local NarrowingStore = require("nattlua.analyzer.narrowing_store")
return function(META--[[#: any]])
	META:AddInitializer(function(self)
		self.constraint_store = ConstraintStore.new()
		self.narrowing_store = NarrowingStore.new()
	end)

	function META:GetArrayLengthFromTable(tbl)
		if tbl.Type ~= "table" then
			if tbl.GetArrayLength then return tbl:GetArrayLength() end

			return LNumber(0)
		end

		local len_type = tbl:GetArrayLength()
		local scope = self:GetScope()
		local len = 0

		if len_type.Type ~= "number" or not len_type:IsLiteral() then
			return len_type
		end

		len = (len_type--[[# as any]]):GetData()
		-- grow
		local cur = len + 1
		local max_grow = 100

		while cur < len + max_grow do
			local val = tbl:GetMutatedValue(LNumber(cur), scope)

			if not val or (val.Type == "symbol" and val:GetData() == nil) then
				break
			end

			cur = cur + 1
		end

		local final_len = cur - 1
		-- shrink
		cur = final_len

		while cur > 0 do
			local val = tbl:GetMutatedValue(LNumber(cur), scope)

			if val and val.Type == "symbol" and val:GetData() == nil then
				cur = cur - 1
			else
				break
			end
		end

		final_len = cur

		if final_len == 0 and not len_type:IsLiteral() then return len_type end

		return LNumber(final_len)
	end

	function META:GetMutatedTableValue(tbl, key)
		return tbl:GetMutatedValue(key, self:GetScope())
	end

	function META:MutateTable(tbl, key, val, from_tracking)
		local scope = self:GetScope()

		if self:IsInUncertainLoop(scope) and tbl:GetCreationScope() then
			if
				(
					val.Type == "number" and
					val:IsDontWiden()
				) or
				scope:Contains(tbl:GetCreationScope())
			then
				val = val:Copy()
			else
				val = val:Widen()
			end
		end

		self:AssertWarning(tbl:Mutate(key, val, scope, from_tracking))
	end

	function META:GetMutatedUpvalue(upvalue)
		return upvalue:GetMutatedValue(self:GetScope())
	end

	function META:MutateUpvalue(upvalue, val, from_tracking)
		local scope = self:GetScope()

		if self:IsInUncertainLoop(scope) and upvalue:GetScope() then
			if (val.Type == "number" and val:IsDontWiden()) or scope:Contains(upvalue:GetScope()) then
				val = val:Copy()
			else
				val = val:Widen()
			end
		end

		self:AssertWarning(upvalue:Mutate(val, scope, from_tracking))

		-- Trigger arithmetic dependency recomputation
		if self.constraint_store then
			self.constraint_store:RecomputeArithmeticFor(upvalue)
		end
	end
end
