local ipairs = _G.ipairs
local LString = require("nattlua.types.string").LString
local Nil = require("nattlua.types.symbol").Nil
local Tuple = require("nattlua.types.tuple").Tuple
local String = require("nattlua.types.string").String
local Union = require("nattlua.types.union").Union
local type_errors = require("nattlua.types.error_messages")
local ConstString = require("nattlua.types.string").ConstString

local function index_table(analyzer, self, key)
	if self:GetMetaTable() and not self:HasKey(key) then
		local index = self:GetMetaTable():Get(ConstString("__index"))

		if index then
			if index == self then return self:Get(key) end

			if
				index.Type == "table" and
				(
					(
						index:GetContract() or
						index
					):HasKey(key) or
					(
						index:GetMetaTable() and
						index:GetMetaTable():HasKey(ConstString("__index"))
					)
				)
			then
				return analyzer:IndexOperator(index:GetContract() or index, key)
			end

			if index.Type == "function" then
				local real_obj = self
				analyzer:PushCurrentType(nil, "table")
				local obj, err = index:Call(analyzer, Tuple({self, key}), analyzer.current_statement)
				analyzer:PopCurrentType("table")

				if not obj then return obj, err end

				local val = obj:Get(1)

				if val and (val.Type ~= "symbol" or val:GetData() ~= nil) then
					if val.Type == "union" and val:CanBeNil() then
						val:RemoveType(Nil())
					end

					analyzer:TrackTableIndex(real_obj, key, val)
					return val
				end
			end
		end
	end

	if analyzer:IsTypesystem() then return self:Get(key) end

	local tracked = analyzer:GetTrackedTableWithKey(self, key)

	if tracked then return tracked end

	local contract = self:GetContract()

	if contract then
		local val, err = contract:Get(key)

		if not val then return val, err end

		if not self.argument_index or contract:IsReferenceArgument() then
			local val = self:GetMutatedValue(key, analyzer:GetScope())

			if val then
				if val.Type == "union" then val = val:Copy(nil, true) end

				if not val:GetContract() then val:SetContract(val) end

				analyzer:TrackTableIndex(self, key, val)
				return val
			end
		end

		if val.Type == "union" then val = val:Copy(nil, true) end

		--TODO: this seems wrong, but it's for deferred analysis maybe not clearing up muations?
		if self:HasMutations() then
			local tracked = self:GetMutatedValue(key, analyzer:GetScope())

			if tracked then val = tracked end
		end

		analyzer:TrackTableIndex(self, key, val)
		return val
	end

	local val = self:GetMutatedValue(key, analyzer:GetScope())

	if key:IsLiteral() then
		local found_key = self:FindKeyValReverse(key)

		if found_key and not found_key.key:IsLiteral() then
			val = Union({Nil(), val})
		end
	end

	if val then
		analyzer:TrackTableIndex(self, key, val)
		return val
	end

	return Nil()
end

local function index_union(analyzer, obj, key)
	local union = Union({})

	for _, obj in ipairs(obj:GetData()) do
		if obj.Type == "tuple" then obj = analyzer:IndexOperator(obj, key) end

		-- if we have a union with an empty table, don't do anything
		-- ie {[number] = string} | {}
		if obj.Type == "table" and obj:IsEmpty() then

		else
			local val, err = analyzer:IndexOperator(obj, key)

			if not val then return val, err end

			union:AddType(val)
		end
	end

	return union
end

local function index_string(analyzer, obj, key)
	local index = obj:GetMetaTable():Get(String("__index"):SetLiteral(true))

	if index:HasKey(key) then return analyzer:IndexOperator(index, key) end

	return obj:Get(key)
end

local function index_tuple(analyzer, obj, key)
	if self:IsRuntime() then self:IndexOperator(obj:GetFirstValue(), key) end

	return obj:Get(key)
end

return {
	Index = function(META)
		function META:IndexOperator(obj, key)
			if obj.Type == "union" then
				return index_union(self, obj, key)
			elseif obj.Type == "tuple" then
				return index_tuple(self, obj, key)
			elseif obj.Type == "table" then
				return index_table(self, obj, key)
			elseif obj.Type == "string" then
				return index_string(self, obj, key)
			end

			return obj:Get(key)
		end
	end,
}