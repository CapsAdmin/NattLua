local setmetatable = _G.setmetatable
local table = _G.table
local ipairs = _G.ipairs
local tostring = _G.tostring
local assert = _G.assert
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local Number = require("nattlua.types.number").Number
local LNumber = require("nattlua.types.number").LNumber
local LString = require("nattlua.types.string").LString
local ConstString = require("nattlua.types.string").ConstString
local Tuple = require("nattlua.types.tuple").Tuple
local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")
local context = require("nattlua.analyzer.context")
local shallow_copy = require("nattlua.other.shallow_copy")
local mutation_solver = require("nattlua.analyzer.mutation_solver")
local Any = require("nattlua.types.any").Any
META.Type = "table"
--[[#type META.@Name = "TTable"]]
--[[#type TTable = META.@Self]]
--[[#local type TBaseType = META.TBaseType]]
META:GetSet("Data", nil--[[# as List<|{key = TBaseType, val = TBaseType}|>]])
META:GetSet("BaseTable", nil--[[# as TTable | nil]])
META:GetSet("ReferenceId", nil--[[# as string | nil]])
META:GetSet("Self", nil--[[# as nil | TTable]])
META:GetSet("Contracts", nil--[[# as List<|TTable|>]])
META:GetSet("CreationScope", nil--[[# as any]])

function META:GetName()
	if not self.Name then
		local meta = self:GetMetaTable()

		if meta and meta ~= self then return meta:GetName() end
	end

	return self.Name
end

function META:SetSelf(tbl)
	tbl:SetMetaTable(self)
	tbl.mutable = true
	tbl:SetContract(tbl)
	self.Self = tbl
end

function META.Equal(a--[[#: TBaseType]], b--[[#: TBaseType]])
	if a.Type ~= b.Type then return false end

	if a:IsUnique() then return a:GetUniqueID() == b:GetUniqueID() end

	if a:GetContract() and a:GetContract().Name then
		if not b:GetContract() or not b:GetContract().Name then
			a.suppress = false
			return false
		end

		-- never called
		a.suppress = false
		return a:GetContract().Name:GetData() == b:GetContract().Name:GetData()
	end

	if a.Name then
		a.suppress = false

		if not b.Name then return false end

		return a.Name:GetData() == b.Name:GetData()
	end

	if a.suppress then return true end

	local adata = a:GetData()
	local bdata = b:GetData()

	if #adata ~= #bdata then return false end

	for i = 1, #adata do
		local akv = adata[i]
		local ok = false

		for i = 1, #bdata do
			local bkv = bdata[i]
			a.suppress = true
			ok = akv.key:Equal(bkv.key) and akv.val:Equal(bkv.val)
			a.suppress = false

			if ok then break end
		end

		if not ok then
			a.suppress = false
			return false
		end
	end

	return true
end

local level = 0

function META:__tostring()
	if self.suppress then return "current_table" end

	self.suppress = true

	if self:GetContract() and self:GetContract().Name then -- never called
		self.suppress = false
		return self:GetContract().Name:GetData()
	end

	if self.Name then
		self.suppress = false
		return self.Name:GetData()
	end

	local meta = self:GetMetaTable()

	if meta then
		local func = meta:Get(ConstString("__tostring"))

		if func then
			local analyzer = context:GetCurrentAnalyzer()

			if analyzer then
				local str = analyzer:Assert(analyzer:Call(func, Tuple({self}))):GetFirstValue()

				if str and str:IsLiteral() then
					self.suppress = false
					return str:GetData()
				end
			end
		end
	end

	local s = {}
	level = level + 1
	local indent = ("\t"):rep(level)

	if #self:GetData() <= 1 then indent = " " end

	local contract = self:GetContract()

	if contract and contract.Type == "table" and contract ~= self then
		for i, keyval in ipairs(contract:GetData()) do
			local key, val = tostring(self:GetData()[i] and self:GetData()[i].key or "nil"),
			tostring(self:GetData()[i] and self:GetData()[i].val or "nil")
			local tkey, tval = tostring(keyval.key), tostring(keyval.val)

			if key == tkey then
				s[i] = indent .. "[" .. key .. "]"
			else
				s[i] = indent .. "[" .. key .. " as " .. tkey .. "]"
			end

			if val == tval then
				s[i] = s[i] .. " = " .. val
			else
				s[i] = s[i] .. " = " .. val .. " as " .. tval
			end
		end
	else
		for i, keyval in ipairs(self:GetData()) do
			local key, val = tostring(keyval.key), tostring(keyval.val)
			s[i] = indent .. "[" .. key .. "]" .. " = " .. val
		end
	end

	level = level - 1
	self.suppress = false

	if #self:GetData() <= 1 then return "{" .. table.concat(s, ",") .. " }" end

	return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function META:GetArrayLength()
	local contract = self:GetContract()

	if contract and contract ~= self then return contract:GetArrayLength() end

	local len = 0

	for _, kv in ipairs(self:GetData()) do
		if kv.key.Type == "number" then
			if kv.key:IsLiteral() then
				-- TODO: not very accurate
				if kv.key:GetMax() then return kv.key:Copy() end

				if len + 1 == kv.key:GetData() then
					len = kv.key:GetData()
				else
					break
				end
			else
				return kv.key
			end
		end
	end

	return LNumber(len)
end

function META:FollowsContract(contract--[[#: TTable]])
	if self:GetContract() == contract then return true end

	do -- todo
		-- i don't think this belongs here
		if not self:GetData()[1] then
			local can_be_empty = true
			contract.suppress = true

			for _, keyval in ipairs(contract:GetData()) do
				if not keyval.val:CanBeNil() then
					can_be_empty = false

					break
				end
			end

			contract.suppress = false

			if can_be_empty then return true end
		end
	end

	for _, keyval in ipairs(contract:GetData()) do
		local res, err = self:FindKeyVal(keyval.key)

		if not res and self:GetMetaTable() then
			res, err = self:GetMetaTable():FindKeyVal(keyval.key)
		end

		if not keyval.val:CanBeNil() then
			if not res then return res, err end

			local ok, err = res.val:IsSubsetOf(keyval.val)

			if not ok then
				return false,
				type_errors.because(type_errors.context("the key", type_errors.subset(res.key, keyval.key)), err)
			end
		end
	end

	for _, keyval in ipairs(self:GetData()) do
		local res, err = contract:FindKeyValReverse(keyval.key)

		if not keyval.val:CanBeNil() then
			if not res then return res, err end

			local ok, err = keyval.val:IsSubsetOf(res.val)

			if not ok then
				return false,
				type_errors.because(type_errors.context("the value", type_errors.subset(res.val, keyval.val)), err)
			end
		end
	end

	return true
end

function META.IsSubsetOf(a--[[#: TBaseType]], b--[[#: TBaseType]])
	if a.suppress then return true, "suppressed" end

	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type == "any" then return true, "b is any " end

	local ok, err = a:IsSameUniqueType(b)

	if not ok then return ok, err end

	if a == b then return true, "same type" end

	if b.Type == "table" then
		if b:GetMetaTable() and b:GetMetaTable() == a then
			return true, "same metatable"
		end

		--if b:GetSelf() and b:GetSelf():Equal(a) then return true end
		local can_be_empty = true
		a.suppress = true

		for _, keyval in ipairs(b:GetData()) do
			if not keyval.val:CanBeNil() then
				can_be_empty = false

				break
			end
		end

		a.suppress = false

		if
			not a:GetData()[1] and
			(
				not a:GetContract() or
				not a:GetContract():GetData()[1]
			)
		then
			if can_be_empty then
				return true, "can be empty"
			else
				return false, type_errors.subset(a, b)
			end
		end

		for _, akeyval in ipairs(a:GetData()) do
			local bkeyval, reason = b:FindKeyValReverse(akeyval.key)

			if not akeyval.val:CanBeNil() then
				if not bkeyval then
					if a.BaseTable and a.BaseTable == b then
						bkeyval = akeyval
					else
						return bkeyval, reason
					end
				end

				a.suppress = true
				local ok, err = akeyval.val:IsSubsetOf(bkeyval.val)
				a.suppress = false

				if not ok then
					return false,
					type_errors.because(type_errors.table_subset(akeyval.key, bkeyval.key, akeyval.val, bkeyval.val), err)
				end
			end
		end

		return true, "all is equal"
	elseif b.Type == "union" then
		local u = Union({a})
		local ok, err = u:IsSubsetOf(b)
		return ok, err or "is subset of b"
	end

	return false, type_errors.subset(a, b)
end

function META:ContainsAllKeysIn(contract--[[#: TTable]])
	for _, keyval in ipairs(contract:GetData()) do
		if keyval.key:IsLiteral() then
			local ok, err = self:FindKeyVal(keyval.key)

			if not ok then
				if
					(
						keyval.val.Type == "symbol" and
						keyval.val:GetData() == nil
					)
					or
					(
						keyval.val.Type == "union" and
						keyval.val:CanBeNil()
					)
					or
					keyval.val.Type == "any"
				then
					return true
				end

				return false,
				type_errors.because(type_errors.key_missing_contract(keyval.key, contract), err)
			end
		end
	end

	return true
end

local function is_literal(obj)
	return ((obj.Type == "number" and not obj.Max) or obj.Type == "string") and obj.Data ~= nil
end

local function AddKey(self, keyval, key, val)
	if not keyval then
		val:SetParent(self)
		key:SetParent(self)
		local keyval = {key = key, val = val}
		table.insert(self.Data, keyval)

		if is_literal(key) then self.LiteralDataCache[key.Data] = keyval end
	else
		if keyval.key:IsLiteral() and keyval.key:Equal(key) then
			keyval.val = val
		else
			keyval.val = Union({keyval.val, val})
		end
	end
end

function META:RemoveRedundantNilValues()
	for i = #self.Data, 1, -1 do
		local keyval = self.Data[i]

		if
			keyval.key.Type == "number" and
			keyval.val.Type == "symbol" and
			keyval.val.Data == nil
		then
			keyval.val:SetParent()
			keyval.key:SetParent()
			table.remove(self.Data, i)

			if is_literal(keyval.key) then
				self.LiteralDataCache[keyval.key.Data] = nil
			end
		else
			break
		end
	end
end

function META:Delete(key--[[#: TBaseType]])
	for i = #self.Data, 1, -1 do
		local keyval = self.Data[i]

		if key:Equal(keyval.key) then
			keyval.val:SetParent()
			keyval.key:SetParent()
			table.remove(self.Data, i)

			if is_literal(keyval.key) then
				self.LiteralDataCache[keyval.key.Data] = nil
			end
		end
	end

	return true
end

function META:GetValueUnion()
	local union = Union()

	for _, keyval in ipairs(self.Data) do
		union:AddType(keyval.val:Copy())
	end

	return union
end

function META:HasKey(key--[[#: TBaseType]])
	return self:FindKeyValReverse(key)
end

function META:IsEmpty()
	if self:GetContract() then return false end

	return self:GetData()[1] == nil
end

function META:CachedKeyEqual(key)
	return self.CachedKeyValues[key.Data]
end

function META:FindKeyVal(key--[[#: TBaseType]])
	if is_literal(key) then
		local keyval = self.LiteralDataCache[key.Data]

		if keyval then return keyval end

		return false, type_errors.table_index(self, key)
	end

	for _, keyval in ipairs(self.Data) do
		if keyval.key:Equal(key) then return keyval end
	end

	if key:IsLiteral() then return false, type_errors.table_index(self, key) end

	local reasons = {}

	for i, keyval in ipairs(self.Data) do
		local ok, reason = keyval.key:IsSubsetOf(key)

		if ok then return keyval end

		reasons[i] = reason
	end

	if not reasons[1] then
		reasons[1] = type_errors.because(type_errors.table_index(self, key), "table is empty")
	end

	return false, type_errors.because(type_errors.table_index(self, key), reasons)
end

function META:FindKeyValReverse(key--[[#: TBaseType]])
	if is_literal(key) and self.LiteralDataCache[key.Data] then
		return self.LiteralDataCache[key.Data]
	end

	for _, keyval in ipairs(self.Data) do
		if key:Equal(keyval.key) then return keyval end
	end

	local reasons = {}

	for i, keyval in ipairs(self.Data) do
		local ok, reason = key:IsSubsetOf(keyval.key)

		if ok then return keyval end

		if i <= 20 then reasons[i] = reason end
	end

	if #reasons > 20 then reasons = {type_errors.table_index(self, key)} end

	if self.BaseTable then
		local ok, reason = self.BaseTable:FindKeyValReverse(key)

		if ok then return ok end

		table.insert(reasons, reason)
	end

	if not reasons[1] then
		reasons[1] = type_errors.because(type_errors.table_index(self, key), "table is empty")
	end

	return false, type_errors.because(type_errors.table_index(self, key), reasons)
end

function META:FindKeyValReverseEqual(key--[[#: TBaseType]])
	if is_literal(key) then
		local keyval = self.LiteralDataCache[key.Data]

		if keyval then return keyval end

		return false, type_errors.table_index(self, key)
	end

	for i, keyval in ipairs(self.Data) do
		local ok = key:Equal(keyval.key)

		if ok then return keyval end
	end

	return false,
	type_errors.because(type_errors.table_index(self, key), "table is empty")
end

function META:Insert(val--[[#: TBaseType]])
	self.size = self.size or 1
	self:Set(LNumber(self.size), val)
	self.size = self.size + 1
end

function META:Set(key--[[#: TBaseType]], val--[[#: TBaseType | nil]], no_delete--[[#: boolean | nil]])
	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
		if
			context:GetCurrentAnalyzer() and
			context:GetCurrentAnalyzer():GetCurrentAnalyzerEnvironment() == "typesystem"
		then
			assert(self["Set" .. key:GetData():sub(2)], key:GetData() .. " is not a function")(self, val)
			return true
		end
	end

	if key.Type == "symbol" and key:GetData() == nil then
		return false, type_errors.invalid_table_index(key)
	end

	if key.Type == "number" and key:IsNan() then
		return false, type_errors.invalid_table_index(key)
	end

	-- delete entry
	if not no_delete and not self:GetContract() then
		if (not val or (val.Type == "symbol" and val:GetData() == nil)) then
			return self:Delete(key)
		end
	end

	if self:GetContract() and self:GetContract().Type == "table" then -- TODO
		local keyval, reason = self:GetContract():FindKeyValReverse(key)

		if not keyval then return keyval, reason end

		local keyval, reason = val:IsSubsetOf(keyval.val)

		if not keyval then return keyval, reason end
	end

	-- if the key exists, check if we can replace it and maybe the value
	local keyval, reason = self:FindKeyValReverse(key)
	AddKey(self, keyval, key, val)
	return true
end

function META:SetExplicit(key--[[#: TBaseType]], val--[[#: TBaseType]])
	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
		assert(self["Set" .. key:GetData():sub(2)], key:GetData() .. " is not a function")(self, val)
		return true
	end

	if key.Type == "symbol" and key:GetData() == nil then
		return false, type_errors.key_nil()
	end

	-- if the key exists, check if we can replace it and maybe the value
	local keyval, reason = self:FindKeyValReverseEqual(key)
	AddKey(self, keyval, key, val)
	return true
end

function META:Get(key--[[#: TBaseType]])
	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
		if
			context:GetCurrentAnalyzer() and
			context:GetCurrentAnalyzer():GetCurrentAnalyzerEnvironment() == "typesystem"
		then
			return assert(self["Get" .. key:GetData():sub(2)], key:GetData() .. " is not a function")(self) or
				Nil()
		end
	end

	if key.Type == "union" then
		if key:IsEmpty() then return false, type_errors.union_key_empty() end

		local union = Union()
		local errors = {}

		for _, k in ipairs(key:GetData()) do
			local obj, reason = self:Get(k)

			if obj then
				union:AddType(obj)
			else
				table.insert(errors, reason)
			end
		end

		if union:GetCardinality() == 0 then return false, errors end

		return union
	end

	if (key.Type == "string" or key.Type == "number") and not key:IsLiteral() then
		local union = Union({Nil()})
		local found_non_literal = false

		for _, keyval in ipairs(self:GetData()) do
			if keyval.key.Type == "union" then
				for _, ukey in ipairs(keyval.key:GetData()) do
					if ukey:IsSubsetOf(key) then union:AddType(keyval.val) end
				end
			elseif keyval.key.Type == key.Type or keyval.key.Type == "any" then
				if keyval.key:IsLiteral() then
					union:AddType(keyval.val)
				else
					found_non_literal = true

					break
				end
			end
		end

		if not found_non_literal then return union end
	end

	if key.Type == "number" and key:GetMin() and key:GetMax() then
		local union = Union()
		local min, max = key:GetMin(), key:GetMax()
		local len = math.abs(min - max)

		if len > 100 then return Any() end

		for i = min, max do
			local res, reason = self:Get(LNumber(i))

			if not res then res = Nil() end

			union:AddType(res)
		end

		return union
	end

	local keyval, reason = self:FindKeyValReverse(key)

	if keyval then return keyval.val end

	if self:GetContract() then
		local keyval, reason = self:GetContract():FindKeyValReverse(key)

		if keyval then return keyval.val end

		return false, reason
	end

	return false, reason
end

function META:IsNumericallyIndexed()
	for _, keyval in ipairs(self:GetData()) do
		if keyval.key.Type ~= "number" then return false end
	end

	return true
end

function META:Widen(from)
	if not from then return self end -- TODO
	if self:Equal(from) then return self end

	if from.Type ~= "table" then return self end

	local self = self:Copy()

	for _, keyval_from in ipairs(from:GetData()) do
		local keyval, reason = self:FindKeyVal(keyval_from.key)

		if keyval then
			keyval.key = keyval.key:Widen(keyval_from.key)
			keyval.val = keyval.val:Widen(keyval_from.val)
		end
	end

	return self
end

function META:CoerceUntypedFunctions(from--[[#: TTable]])
	assert(from.Type == "table")

	for _, kv in ipairs(self:GetData()) do
		local kv_from, reason = from:FindKeyValReverse(kv.key)

		if not kv_from then return nil, reason end

		if kv.val.Type == "function" and kv_from.val.Type == "function" then
			kv.val:SetInputSignature(kv_from.val:GetInputSignature())
			kv.val:SetOutputSignature(kv_from.val:GetOutputSignature())
			kv.val:SetExplicitOutputSignature(true)
			kv.val:SetExplicitInputSignature(true)
			kv.val:SetCalled(false)
		end
	end

	return true
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables--[[#: nil | boolean]])
	map = map or {}
	local copy = META.New()
	map[self] = map[self] or copy

	for i, keyval in ipairs(self.Data) do
		local k, v = keyval.key, keyval.val
		k = map[keyval.key] or k:Copy(map, copy_tables)
		map[keyval.key] = map[keyval.key] or k
		v = map[keyval.val] or v:Copy(map, copy_tables)
		map[keyval.val] = map[keyval.val] or v
		copy.Data[i] = {key = k, val = v}

		if is_literal(k) then copy.LiteralDataCache[k.Data] = copy.Data[i] end
	end

	copy:CopyInternalsFrom(self)
	copy.PotentialSelf = self.PotentialSelf
	copy.mutable = self.mutable
	copy.mutations = self.mutations or false
	copy:SetCreationScope(self:GetCreationScope())
	copy.BaseTable = self.BaseTable
	copy.UniqueID = self.UniqueID

	--[[
		
		copy.argument_index = self.argument_index
		copy.parent = self.parent
		copy.reference_id = self.reference_id
		]] if self.Self then copy:SetSelf(self.Self:Copy()) end

	if self.MetaTable then copy:SetMetaTable(self.MetaTable) end

	return copy
end

function META:GetContract()
	return self.Contracts[#self.Contracts] or self.Contract
end

function META:PushContract(contract)
	table.insert(self.Contracts, contract)
end

function META:PopContract()
	table.remove(self.Contracts)
end

--[[#type META.@Self.suppress = boolean]]

function META:HasLiteralKeys()
	if self.suppress then return true end

	local contract = self:GetContract()

	if contract and contract ~= self and not contract:HasLiteralKeys() then
		return false
	end

	for _, v in ipairs(self:GetData()) do
		if
			v.val ~= self and
			v.key ~= self and
			v.val.Type ~= "function" and
			v.key.Type ~= "function"
		then
			self.suppress = true
			local ok, reason = v.key:IsLiteral()
			self.suppress = false

			if not ok then
				return false,
				type_errors.because(type_errors.context("the key", type_errors.not_literal(v.key)), reason)
			end
		end
	end

	return true
end

function META:IsLiteral()
	if self.suppress then return true end

	if self:GetContract() then return false end

	for _, v in ipairs(self:GetData()) do
		if
			v.val ~= self and
			v.key ~= self and
			v.val.Type ~= "function" and
			v.key.Type ~= "function"
		then
			self.suppress = true
			local ok, reason = v.key:IsLiteral()
			self.suppress = false

			if not ok then
				return false,
				type_errors.because(type_errors.context("the key", type_errors.not_literal(v.key)), reason)
			end

			self.suppress = true
			local ok, reason = v.val:IsLiteral()
			self.suppress = false

			if not ok then
				return false,
				type_errors.because(type_errors.context("the value", type_errors.not_literal(v.val)), reason)
			end
		end
	end

	return true
end

function META:IsFalsy()
	return false
end

function META:IsTruthy()
	return true
end

local function unpack_keyval(keyval--[[#: ref {key = any, val = any}]])
	local key, val = keyval.key, keyval.val
	return key, val
end

function META.Extend(a--[[#: TTable]], b--[[#: TTable]])
	assert(b.Type == "table")
	local map = {}

	if a:GetContract() then
		if a == a:GetContract() then
			a:SetContract()
			a = a:Copy()
			a:SetContract(a)
		end

		a = a:GetContract()
	else
		a = a:Copy(map)
	end

	map[b] = a
	b = b:Copy(map)

	for _, keyval in ipairs(b:GetData()) do
		local ok, reason = a:SetExplicit(unpack_keyval(keyval))

		if not ok then return ok, reason end
	end

	return a
end

function META.Union(a--[[#: TTable]], b--[[#: TTable]])
	assert(b.Type == "table")
	local copy = META.New()

	for _, keyval in ipairs(a:GetData()) do
		copy:Set(unpack_keyval(keyval))
	end

	for _, keyval in ipairs(b:GetData()) do
		copy:Set(unpack_keyval(keyval))
	end

	return copy
end

function META.LogicalComparison(l, r, op, env)
	if op == "==" then
		if env == "runtime" then
			if l:GetReferenceId() and r:GetReferenceId() then
				return l:GetReferenceId() == r:GetReferenceId()
			end

			return nil
		elseif env == "typesystem" then
			return l:IsSubsetOf(r) and r:IsSubsetOf(l)
		end
	end

	return false, type_errors.binary(op, l, r)
end

do
	local function initialize_table_mutation_tracker(tbl, scope, key, hash)
		tbl.mutations = tbl.mutations or {}
		tbl.mutations[hash] = tbl.mutations[hash] or {}

		if tbl.mutations[hash][1] == nil then
			if tbl.Type == "table" then
				-- initialize the table mutations with an existing value or nil
				local val = (tbl:GetContract() or tbl):Get(key) or Nil()

				if
					tbl:GetCreationScope() and
					not scope:IsCertainFromScope(tbl:GetCreationScope())
				then
					scope = tbl:GetCreationScope()
				end

				table.insert(tbl.mutations[hash], {scope = scope, value = val, contract = tbl:GetContract(), key = key})
			end
		end
	end

	function META:GetMutatedValue(key, scope)
		local hash = key:GetHash()

		if hash == nil then
			hash = key:GetUpvalue() and key:GetUpvalue():GetKey()

			if not hash then return end

			return
		end

		initialize_table_mutation_tracker(self, scope, key, hash)
		return mutation_solver(shallow_copy(self.mutations[hash]), scope, self)
	end

	function META:Mutate(key, val, scope, from_tracking)
		local hash = key:GetHash()

		if hash == nil then
			hash = key:GetUpvalue() and key:GetUpvalue():GetKey()

			if not hash then return end

			return
		end

		initialize_table_mutation_tracker(self, scope, key, hash)
		table.insert(self.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking, key = key})

		if from_tracking then scope:AddTrackedObject(self) end
	end

	function META:ClearMutations()
		self.mutations = false
	end

	function META:SetMutations(tbl)
		self.mutations = tbl
	end

	function META:GetMutations()
		return self.mutations
	end

	function META:HasMutations()
		return self.mutations ~= false
	end

	function META:GetMutatedFromScope(scope, done)
		if not self.mutations then return self end

		done = done or {}
		local out = META.New()

		if done[self] then return done[self] end

		done[self] = out

		for hash, mutations in pairs(self.mutations) do
			for _, mutation in ipairs(mutations) do
				local key = mutation.key
				local val = self:GetMutatedValue(key, scope)

				if val then
					if done[val] then break end

					if val.Type == "union" then
						local union = Union()

						for _, val in ipairs(val:GetData()) do
							if val.Type == "table" then
								union:AddType(val:GetMutatedFromScope(scope, done))
							else
								union:AddType(val)
							end
						end

						out:Set(key, union)
					elseif val.Type == "table" then
						out:Set(key, val:GetMutatedFromScope(scope, done))
					else
						out:Set(key, val)
					end

					break
				end
			end
		end

		return out
	end
end

do
	--[[#type TTable.disabled_unique_id = number | nil]]
	META:GetSet("UniqueID", false--[[# as false | number]])
	local ref = 0

	function META:MakeUnique(b--[[#: boolean]])
		if b then
			self.UniqueID = ref
			ref = ref + 1
		else
			self.UniqueID = false
		end

		return self
	end

	function META:IsUnique()
		return self.UniqueID ~= false
	end

	function META:DisableUniqueness()
		self.disabled_unique_id = self.UniqueID
		self.UniqueID = false
	end

	function META:EnableUniqueness()
		self.UniqueID = self.disabled_unique_id
	end

	function META:GetHash()
		if self.UniqueID ~= false then return self.UniqueID end

		return nil
	end

	function META.IsSameUniqueType(a--[[#: TTable]], b--[[#: TTable]])
		if a.UniqueID and not b.UniqueID then
			return false, type_errors.unique_type_type_mismatch(a, b)
		end

		if a.UniqueID ~= b.UniqueID then
			return false, type_errors.unique_type_mismatch(a, b)
		end

		return true
	end
end

function META.New()
	return setmetatable(
		{
			Data = {},
			LiteralDataCache = {},
			Contracts = {},
			Falsy = false,
			Truthy = false,
			ReferenceType = false,
			suppress = false,
			mutations = false,
			tracked_stack = false,
			PotentialSelf = false,
			falsy_union = false,
			truthy_union = false,
			mutable = false,
			string_metatable = false,
			argument_index = false,
			size = false,
			parent_table = false,
			disabled_unique_id = false,
			co_func = false,
			right_source = false,
			left_source = false,
			func = false,
		},
		META
	)
end

return {Table = META.New}
