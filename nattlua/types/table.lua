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
local String = require("nattlua.types.string").String
local ConstString = require("nattlua.types.string").ConstString
local Tuple = require("nattlua.types.tuple").Tuple
local type_errors = require("nattlua.types.error_messages")
local context = require("nattlua.analyzer.context")
local mutation_solver = require("nattlua.analyzer.mutation_solver")
local table_sort = require("nattlua.other.sort")
local Any = require("nattlua.types.any").Any
local math_abs = math.abs
local math_huge = math.huge
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#type TTable = META.@Self]]
--[[#type TTable.suppress = boolean]]
--[[#type TTable.mutable = boolean]]
--[[#type TTable.mutations = Map<|
		TBaseType,
		List<|{scope = TBaseType, value = TBaseType, contract = TBaseType, key = TBaseType}|>
	|> | false]]
--[[#type TTable.LiteralDataCache = Map<|TBaseType, TBaseType|>]]
--[[#type TTable.PotentialSelf = TBaseType | false]]
--[[#type META.@Name = "TTable"]]
META.Type = "table"
META:GetSet("Data", nil--[[# as List<|{key = TBaseType, val = TBaseType}|>]])
META:GetSet("BaseTable", nil--[[# as TTable | false]])
META:GetSet("ReferenceId", nil--[[# as string | false]])
META:GetSet("Self", nil--[[# as false | TTable]])
META:GetSet("Contracts", nil--[[# as List<|TTable|>]])
META:GetSet("CreationScope", nil--[[# as any]])
META:GetSet("AnalyzerEnvironment", false--[[# as false | "runtime" | "typesystem"]])
META:GetSet("MutationLimit", 100)

do -- comes from tbl.@Name = "my name"
	META:GetSet("Name", false--[[# as false | TBaseType]])

	function META:SetName(name--[[#: TBaseType | false]])
		if name then assert(name:IsLiteral()) end

		self.Name = name
	end
end

function META:GetName()
	if not self.Name then
		local meta = self:GetMetaTable()

		if meta and meta ~= self then return meta:GetName() end
	end

	return self.Name
end

do
	META:GetSet("MetaTable", false--[[# as TBaseType | false]])

	function META:GetMetaTable()
		local contract = self:GetContract()

		if contract and contract.Type == "table" and contract.MetaTable then
			return contract.MetaTable
		end

		return self.MetaTable
	end
end

function META:SetSelf(tbl--[[#: TTable]])
	tbl:SetMetaTable(self)
	tbl.mutable = true
	tbl:SetContract(tbl)
	self.Self = tbl
end

function META:SetSelf2(tbl)
	self.Self2 = tbl
end

function META:GetSelf2()
	return self.Self2
end

function META.Equal(a--[[#: TBaseType]], b--[[#: TBaseType]], visited--[[#: Map<|TBaseType, boolean|>]])
	if a.Type ~= b.Type then return false, "types differ" end

	if a:IsUnique() then
		return a:GetUniqueID() == b:GetUniqueID(), "unique ids match"
	end

	do
		local contract = a:GetContract()

		if contract and contract.Type == "table" and contract.Name then
			if not b:GetContract() or not b:GetContract().Name then
				return false, "contract name mismatch"
			end

			-- never called
			return contract.Name:GetData() == b:GetContract().Name:GetData(),
			"contract names match"
		end
	end

	if a.Name then
		if not b.Name then return false, "name property mismatch" end

		return a.Name:GetData() == b.Name:GetData(), "names match"
	end

	visited = visited or {}

	if visited[a] then return true, "circular reference detected" end

	visited[a] = true
	local adata = a:GetData()
	local bdata = b:GetData()

	if #adata ~= #bdata then return false, "table size mismatch" end

	local matched = {}

	for i = 1, #adata do
		local akv = adata[i]
		local ok = false

		for i = 1, #bdata do
			if not matched[i] then -- Skip already matched entries
				local bkv = bdata[i]
				local ok_key, reason_key = akv.key:Equal(bkv.key, visited)
				local ok_val, reason_val = akv.val:Equal(bkv.val, visited)

				if ok_key and ok_val then
					ok = true
					matched[i] = true

					break
				end
			end
		end

		if not ok then
			return false, "table key-value mismatch"
		end
	end

	return true, "all table entries match"
end

function META:GetHash(visited)
	if self:IsUnique() then return "{*" .. self:GetUniqueID() .. "*}" end

	local contract = self:GetContract()

	if contract and contract.Type == "table" and contract.Name then
		return "{*" .. contract.Name:GetData() .. "*}"
	end

	if self.Name then return "{*" .. self.Name:GetData() .. "*}" end

	visited = visited or {}

	if visited[self] then return visited[self] end

	visited[self] = "*circular*"
	local data = self:GetData()
	local entries = {}

	for i = 1, #data do
		table.insert(entries, data[i].key:GetHash(visited) .. "=" .. data[i].val:GetHash(visited))
	end

	table_sort(entries)
	visited[self] = "{" .. table.concat(entries, ",") .. "}"
	return visited[self]
end

local level = 0

function META:__tostring()
	if self.suppress then return "current_table" end

	self.suppress = true

	do
		local contract = self:GetContract()

		if contract and contract.Name then -- never called
			self.suppress = false
			return tostring(contract.Name:GetData())
		end
	end

	if self.Name then
		self.suppress = false
		return tostring(self.Name:GetData())
	end

	local meta = self:GetMetaTable()

	if meta then
		local func = meta:Get(ConstString("__tostring"))

		if func then
			local analyzer = context:GetCurrentAnalyzer()

			if analyzer then
				local str = analyzer:GetFirstValue(analyzer:Call(func, Tuple({self})))

				if str and str.Type == "string" and str:IsLiteral() then
					self.suppress = false
					return tostring(str:GetData())
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
			local table_kv = self:FindKeyValExact(keyval.key)
			local key = tostring(table_kv and table_kv.key or "nil")
			local val = tostring(table_kv and table_kv.val or "nil")
			local tkey = tostring(keyval.key)
			local tval = tostring(keyval.val)

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
		if kv.key:IsNumeric() then
			if kv.key:IsLiteral() then
				-- TODO: not very accurate
				if kv.key.Type == "range" then return kv.key:Copy() end

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
	if self.suppress then return true end

	if self:GetContract() == contract then return true end

	if not self:GetData()[1] and contract:CanBeEmpty() then return true end

	for _, keyval in ipairs(contract:GetData()) do
		local required_key = keyval.key

		if required_key:IsLiteral() then
			if not keyval.val:IsNil() then
				local res, err = self:FindKeyValExact(required_key)

				if not res and self:GetMetaTable() then
					res, err = self:GetMetaTable():FindKeyValExact(required_key)
				end

				if not res then return res, err end

				local ok, err = res.val:IsSubsetOf(keyval.val)

				if not ok then
					return false,
					type_errors.because(type_errors.context("the key", type_errors.subset(res.key, keyval.key)), err)
				end
			end
		else
			local found_anything = false

			for _, keyval2 in ipairs(self:GetData()) do
				if keyval2.key:IsSubsetOf(required_key) then
					self.suppress = true
					local ok, err = keyval2.val:IsSubsetOf(keyval.val)
					self.suppress = false
					found_anything = true

					if not ok then
						return false,
						type_errors.because(type_errors.context("the key", type_errors.subset(keyval2.key, keyval.key)), err)
					end
				end
			end

			if not found_anything then
				return false, type_errors.table_index(self, required_key)
			end
		end
	end

	for _, keyval in ipairs(self:GetData()) do
		if not keyval.val:IsNil() then
			local res, err = contract:FindKeyValExact(keyval.key)

			-- it's ok if the key is not found, as we're doing structural checking
			if res then
				-- if it is found, we make sure its type matches
				local ok, err = keyval.val:IsSubsetOf(res.val)

				if not ok then
					return false,
					type_errors.because(type_errors.context("the value", type_errors.subset(res.val, keyval.val)), err)
				end
			end
		end
	end

	return true
end

function META:CanBeEmpty()
	for _, keyval in ipairs(self:GetData()) do
		if not keyval.val:CanBeNil() then return false end
	end

	return true
end

function META:IsEmpty()
	if
		self:GetContract() and
		self:GetContract() ~= self and
		self:GetContract().Type == "table"
	then
		return self:GetContract():IsEmpty()
	end

	return not self.Data[1]
end

function META.IsSubsetOf(a--[[#: TBaseType]], b--[[#: TBaseType]])
	if a.suppress then return true, "suppressed" end

	if b.Type == "tuple" then b = b:GetWithNumber(1) end

	if b.Type == "any" then return true, "b is any" end

	if b.Type == "table" then
		if a == b then return true, "same type" end

		local ok, err = a:IsSameUniqueType(b)

		if not ok then return ok, err end
	end

	if b.Type == "table" then
		if b:GetMetaTable() and b:GetMetaTable() == a then
			return true, "same metatable"
		end

		if a:IsEmpty() then
			if b:CanBeEmpty() then return true, "can be empty" end

			return false, type_errors.subset(a, b)
		end

		for _, bkeyval in ipairs(b:GetData()) do
			local akeyval, reason = a:FindKeyValWide(bkeyval.key, true)

			if not bkeyval.val:CanBeNil() then
				if not akeyval then
					if b.BaseTable and b.BaseTable == a then
						akeyval = bkeyval
					else
						return akeyval, reason
					end
				end

				a.suppress = true
				local ok, err = akeyval.val:IsSubsetOf(bkeyval.val)
				a.suppress = false

				if not ok then
					return false,
					type_errors.because(type_errors.table_subset(bkeyval.key, akeyval.key, bkeyval.val, akeyval.val), err)
				end
			end
		end

		if b:IsNumericallyIndexed() and not a:IsNumericallyIndexed() then
			return false, type_errors.subset(a, b)
		end

		return true, "all is equal"
	elseif b.Type == "union" then
		for _, obj in ipairs(b.Data) do
			local ok, err = a:IsSubsetOf(obj)

			if ok then return true, "a is subset of one in the union" end
		end

		return false, type_errors.subset(a, b)
	end

	return false, type_errors.subset(a, b)
end

function META:ContainsAllKeysIn(contract--[[#: TTable]])
	for _, keyval in ipairs(contract:GetData()) do
		if keyval.key:IsLiteral() then
			local ok, err = self:FindKeyValExact(keyval.key)

			if not ok then
				if keyval.val:CanBeNil() then return true end

				return false,
				type_errors.because(type_errors.key_missing_contract(keyval.key, contract), err)
			end
		end
	end

	return true
end

local function get_hash(key)
	if key.Type ~= "table" and key.Type ~= "function" and key.Type ~= "tuple" then
		return key:GetHash()
	end

	return nil
end

local function write_cache(self, key, val)
	local hash = get_hash(key)

	if hash then self.LiteralDataCache[hash] = val end
end

local function read_cache(self, key)
	local hash = get_hash(key)

	if hash then
		local val = self.LiteralDataCache[hash]

		if val then return val end

		return false, type_errors.table_index(self, key)
	end

	return nil
end

local function read_cache_no_error(self, key)
	local hash = get_hash(key)

	if hash then return self.LiteralDataCache[hash] end

	return nil
end

local function AddKey(self, keyval, key, val)
	if not keyval then
		val:SetParent(self)
		key:SetParent(self)
		local keyval = {key = key, val = val}
		table.insert(self.Data, keyval)
		write_cache(self, key, keyval)
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
			keyval.val:IsNil()
		then
			keyval.val:SetParent()
			keyval.key:SetParent()
			table.remove(self.Data, i)
			write_cache(self, keyval.key, nil)
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
			write_cache(self, keyval.key, nil)
		end
	end

	return true
end

do
	function META:Insert(val--[[#: TBaseType]])
		self.size = self.size or 1
		self:Set(LNumber(self.size), val)
		self.size = self.size + 1
	end

	function META:Concat(separator--[[#: TBaseType]])
		if not self:IsLiteral() then return String() end

		if
			separator and
			(
				separator.Type ~= "string" or
				not separator:IsLiteral()
			)
			and
			not separator.Type ~= "symbol" and
			separator:IsBoolean()
		then
			return String()
		end

		local out = {}

		for i, keyval in ipairs(self:GetData()) do
			if not keyval.val:IsLiteral() or keyval.val.Type == "union" then
				return String()
			end

			out[i] = keyval.val:GetData()
		end

		return table.concat(out, separator and separator:GetData() or nil)
	end

	function META:Remove(index--[[#: TBaseType]])
		local index_num = index:GetData()
		local removed_val = nil
		local found_index = nil

		for i = #self.Data, 1, -1 do
			local keyval = self.Data[i]

			if keyval.key.Type == "number" and keyval.key:IsLiteral() then
				local key_num = keyval.key:GetData()

				if key_num == index_num then
					removed_val = keyval.val
					found_index = i
					keyval.val:SetParent()
					keyval.key:SetParent()
					table.remove(self.Data, i)
					write_cache(self, keyval.key, nil)

					break
				end
			end
		end

		if not found_index then
			return false, type_errors.table_index(self, index)
		end

		for i, keyval in ipairs(self.Data) do
			if keyval.key.Type == "number" and keyval.key:IsLiteral() then
				local key_num = keyval.key:GetData()

				if key_num > index_num then
					write_cache(self, keyval.key, nil)
					local new_key = LNumber(key_num - 1)
					new_key:SetParent(self)
					keyval.key = new_key
					write_cache(self, new_key, keyval)
				end
			end
		end

		if self.size and self.size > index_num then self.size = self.size - 1 end

		return removed_val
	end
end

function META:GetValueUnion()
	local union = Union()

	for _, keyval in ipairs(self.Data) do
		union:AddType(keyval.val:Copy())
	end

	return union
end

function META:HasKey(key--[[#: TBaseType]])
	return self:FindKeyValWide(key)
end

function META:FindKeyValExact(key--[[#: TBaseType]])
	local keyval, reason = read_cache(self, key)

	if keyval then return keyval, reason end

	local reasons = {}

	for i, keyval in ipairs(self.Data) do
		local ok, reason = keyval.key:IsSubsetOf(key)

		if ok then return keyval end

		if i <= 20 then reasons[i] = reason end
	end

	if not reasons[1] then
		reasons[1] = type_errors.because(type_errors.table_index(self, key), "table is empty")
	end

	return false, type_errors.because(type_errors.table_index(self, key), reasons)
end

function META:FindKeyValWide(key--[[#: TBaseType]], reverse--[[#: boolean | nil]])
	local keyval = read_cache(self, key)

	if keyval then return keyval end

	local reasons = {}

	for i, keyval in ipairs(self.Data) do
		if key:Equal(keyval.key) then return keyval end

		local ok, reason

		if reverse then
			ok, reason = keyval.key:IsSubsetOf(key)
		else
			ok, reason = key:IsSubsetOf(keyval.key)
		end

		if ok then return keyval end

		if i <= 20 then reasons[i] = reason end
	end

	if #reasons > 20 then reasons = {type_errors.table_index(self, key)} end

	if self.BaseTable then
		local ok, reason = self.BaseTable:FindKeyValWide(key)

		if ok then return ok end

		table.insert(reasons, reason)
	end

	if not reasons[1] then
		reasons[1] = type_errors.because(type_errors.table_index(self, key), "table is empty")
	end

	return false, type_errors.because(type_errors.table_index(self, key), reasons)
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

	if key.Type == "symbol" and key:IsNil() then
		return false, type_errors.invalid_table_index(key)
	end

	if key.Type == "number" and key:IsNan() then
		return false, type_errors.invalid_table_index(key)
	end

	-- delete entry
	if not no_delete and not self:GetContract() then
		if (not val or (val.Type == "symbol" and val:IsNil())) then
			return self:Delete(key)
		end
	end

	if self:GetContract() and self:GetContract().Type == "table" then -- TODO
		local keyval, reason = self:GetContract():FindKeyValWide(key)

		if not keyval then return keyval, reason end

		local keyval, reason = val:IsSubsetOf(keyval.val)

		if not keyval then return keyval, reason end
	end

	-- if the key exists, check if we can replace it and maybe the value
	local keyval, reason = self:FindKeyValWide(key)
	AddKey(self, keyval, key, val)
	return true
end

function META:SetExplicit(key--[[#: TBaseType]], val--[[#: TBaseType]])
	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
		assert(self["Set" .. key:GetData():sub(2)], key:GetData() .. " is not a function")(self, val)
		return true
	end

	if key.Type == "symbol" and key:IsNil() then
		return false, type_errors.key_nil()
	end

	-- if the key exists, check if we can replace it and maybe the value
	AddKey(self, read_cache_no_error(self, key), key, val)
	return true
end

function META:Get(key--[[#: TBaseType | TString]])
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

	if key.Type == "range" then
		local union = Union()
		local min, max = key:GetMin(), key:GetMax()
		local len = math_abs(min - max)

		if len == math_huge or len == -math_huge then
			union:AddType(Nil())

			for _, keyval in ipairs(self:GetData()) do
				if keyval.key.Type == "number" then union:AddType(keyval.val) end
			end

			return union
		end

		if len > 100 then return Any() end

		for i = min, max do
			local res, reason = self:Get(LNumber(i))

			if not res then res = Nil() end

			union:AddType(res)
		end

		return union
	end

	if key.Type == "any" then
		local union = Union({Nil()})

		for _, keyval in ipairs(self:GetData()) do
			union:AddType(keyval.val)
		end

		return union
	end

	local keyval, reason = self:FindKeyValWide(key)

	if keyval then return keyval.val end

	if self:GetContract() then
		local keyval, reason = self:GetContract():FindKeyValWide(key)

		if keyval then return keyval.val end

		return false, reason
	end

	return false, reason
end

function META:IsNumericallyIndexed()
	for _, keyval in ipairs(self:GetData()) do
		if not keyval.key:IsNumeric() then return false end -- TODO, check if there are holes?
	end

	return true
end

function META:CopyLiteralness(from)
	if from.Type ~= self.Type then return self end

	if self:Equal(from) then return self end

	local self = self:Copy()

	for _, keyval_from in ipairs(from:GetData()) do
		local keyval, reason = self:FindKeyValExact(keyval_from.key)

		if keyval then
			keyval.key = keyval.key:CopyLiteralness(keyval_from.key)
			keyval.val = keyval.val:CopyLiteralness(keyval_from.val)
		end
	end

	return self
end

function META:CopyLiteralness2(from)
	if from.Type ~= self.Type then return self end

	if self:Equal(from) then return self end

	local ref_map = {[from] = self}

	for _, keyval_from in ipairs(from:GetData()) do
		local keyval, reason = self:FindKeyValExact(keyval_from.key)

		if keyval then
			self:Delete(keyval.key)
			AddKey(self, nil, keyval_from.key:Copy(ref_map), keyval_from.val:Copy(ref_map))
		end
	end

	return self
end

function META:CoerceUntypedFunctions(from--[[#: TTable]])
	assert(from.Type == "table")

	for _, kv in ipairs(self:GetData()) do
		local kv_from, reason = from:FindKeyValWide(kv.key)

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

local function copy_val(val, map, copy_tables)
	if not val then return val end

	if map[val] then
		-- if the specific reference is already copied, just return it
		return map[val]
	end

	map[val] = val:Copy(map, copy_tables)
	return map[val]
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables)
	map = map or {}

	if map[self] then return map[self] end

	local copy = META.New()
	map[self] = copy -- map any lua references from self to this new copy
	for i, keyval in ipairs(self.Data) do
		local k = copy_val(keyval.key, map, copy_tables)
		local v = copy_val(keyval.val, map, copy_tables)
		copy.Data[i] = {key = k, val = v}
		write_cache(copy, k, copy.Data[i])
	end

	copy:CopyInternalsFrom(self)

	if self.Self then
		local tbl = self.Self
		local m, c = tbl.MetaTable, tbl.Contract
		tbl.MetaTable = false
		tbl.Contract = false
		local tbl_copy = copy_val(self.Self, map, copy_tables)
		tbl.MetaTable = m
		tbl.Contract = c
		copy:SetSelf(tbl_copy)
	end

	copy.Self2 = self.Self2
	copy.MetaTable = self.MetaTable --copy_val(self.MetaTable, map, copy_tables)
	copy.Contract = self:GetContract() --copy_val(self.Contract, map, copy_tables)
	copy:SetAnalyzerEnvironment(self:GetAnalyzerEnvironment())
	copy.PotentialSelf = copy_val(self.PotentialSelf, map, copy_tables)
	copy.mutable = self.mutable
	copy.mutations = self.mutations or false
	copy:SetCreationScope(self:GetCreationScope())
	copy.BaseTable = self.BaseTable
	copy.UniqueID = self.UniqueID
	copy:SetName(self:GetName())
	copy:SetTypeOverride(self:GetTypeOverride())
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
	local own_contract = a:GetContract() == a
	a = a:Copy()
	b = b:Copy()
	local ref_map = {[b] = a}

	for _, keyval in ipairs(b:GetData()) do
		local key, val = keyval.key:Copy(ref_map), keyval.val:Copy(ref_map)
		local ok, reason = a:SetExplicit(key, val)

		if not ok then return ok, reason end
	end

	if own_contract then a.Contract = a end

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
		local hash = key:GetHashForMutationTracking()

		if hash == nil then
			hash = key:GetUpvalue() and key:GetUpvalue():GetKey()

			if not hash then return end

			return
		end

		initialize_table_mutation_tracker(self, scope, key, hash)
		return mutation_solver(self.mutations[hash], scope, self)
	end

	function META:Mutate(key, val, scope, from_tracking)
		local hash = key:GetHashForMutationTracking()

		if hash == nil then return true end

		initialize_table_mutation_tracker(self, scope, key, hash)

		if #self.mutations[hash] > self:GetMutationLimit() then
			return false, type_errors.too_many_mutations()
		end

		table.insert(self.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking, key = key})

		if from_tracking then scope:AddTrackedObject(self) end

		return true
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
	--[[#type TTable.disabled_unique_id = number | false]]
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

	function META:GetHashForMutationTracking()
		if self.UniqueID ~= false then return self.UniqueID end

		return nil
	end

	function META.IsSameUniqueType(a--[[#: TTable]], b--[[#: TTable]])
		if b.Type ~= "table" then return false end

		if a.UniqueID and not b.UniqueID then
			return false, type_errors.unique_type_type_mismatch(a, b)
		end

		if a.UniqueID ~= b.UniqueID then
			return false, type_errors.unique_type_mismatch(a, b)
		end

		return true
	end
end

do -- comes from tbl.@TypeOverride = "my name"
	META:GetSet("TypeOverride", false--[[# as false | TBaseType]])

	function META:SetTypeOverride(name--[[#: false | TBaseType]])
		self.TypeOverride = name
	end
end

function META:GetLuaType()
	local contract = self:GetContract()

	if contract then
		local to = contract.TypeOverride

		if to and to.Type == "string" and to.Data then return to.Data end
	end

	local to = self.TypeOverride
	return to and to.Type == "string" and to.Data or self.Type
end

function META.New()
	return META.NewObject(
		{
			Type = "table",
			Data = {},
			CreationScope = false,
			AnalyzerEnvironment = false,
			Parent = false,
			Upvalue = false,
			UniqueID = false,
			Name = false,
			Self = false,
			Self2 = false,
			LiteralDataCache = {},
			Contracts = {},
			Falsy = false,
			TypeOverride = false,
			Truthy = false,
			ReferenceType = false,
			suppress = false,
			mutations = false,
			PotentialSelf = false,
			mutable = false,
			string_metatable = false,
			argument_index = false,
			size = false,
			disabled_unique_id = false,
			co_func = false,
			func = false,
			BaseTable = false,
			ReferenceId = false,
			MetaTable = false,
			Contract = false,
			MutationLimit = 100,
		}
	)
end

return {Table = META.New}
