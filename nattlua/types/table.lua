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
local error_messages = require("nattlua.error_messages")
local context = require("nattlua.analyzer.context")
local mutation_solver = require("nattlua.analyzer.mutation_solver")
local table_sort = require("nattlua.other.sort")
local Any = require("nattlua.types.any").Any
local shared = require("nattlua.types.shared")
local math_abs = math.abs
local math_huge = math.huge
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#local type TTable = META.@SelfArgument]]
--[[#type TTable.Type = "table"]]
--[[#type TTable.suppress = boolean]]
--[[#type TTable.mutations = Map<|
		TBaseType,
		List<|{scope = TBaseType, value = TBaseType, contract = TBaseType, key = TBaseType}|>
	|> | false]]
--[[#type TTable.literal_data_cache = Map<|TBaseType, {key = TBaseType, val = TBaseType} | nil|>]]
--[[#type TTable.potential_self = TBaseType | false]]
--[[#type TTable.size = number | false]]
--[[#type TTable.disabled_unique_id = number | false]]
--[[#type META.@Name = "TTable"]]
META.Type = "table"
META:GetSet("Data", nil--[[# as List<|{key = TBaseType, val = TBaseType}|>]])
META:GetSet("ReferenceId", nil--[[# as string | false]])
META:GetSet("Contracts", nil--[[# as List<|TTable|>]])
META:GetSet("CreationScope", nil--[[# as any]])
META:GetSet("SelfArgument", nil--[[# as any]])
META:GetSet("AnalyzerEnvironment", false--[[# as false | "runtime" | "typesystem"]])
META:GetSet("MutationLimit", 100)

do -- comes from tbl.@Name = "my name"
	META:GetSet("Name", false--[[# as false | TBaseType]])

	function META:SetName(name--[[#: TBaseType | false]])
		if name then assert(name:IsLiteral()) end

		self.Name = name
	end
end

function META:GetName()--[[#: TBaseType | false]]
	if not self.Name then
		local meta = self:GetMetaTable()

		if meta and meta ~= self and meta.Type == "table" then
			return (meta--[[# as TTable]]):GetName()
		end
	end

	return self.Name
end

do
	META:GetSet("MetaTable", false--[[# as TBaseType | false]])

	function META:GetMetaTable()--[[#: TBaseType | false]]
		local contract = self:GetContract()

		if contract and contract.Type == "table" and (contract--[[# as TTable]]).MetaTable then
			return (contract--[[# as TTable]]).MetaTable
		end

		return self.MetaTable
	end
end

function META.Equal(
	a--[[#: TTable]],
	b--[[#: TBaseType]],
	visited--[[#: Map<|TBaseType, boolean|> | nil]]
)--[[#: boolean, string | nil]]
	return shared.Equal(a, b, visited)
end

function META:GetHash(visited--[[#: Map<|TBaseType, string|> | nil]])--[[#: string]]
	if self:IsUnique() then
		return "{*" .. (self:GetUniqueID()--[[# as any]]) .. "*}"
	end

	local contract = self:GetContract()

	if contract and contract.Type == "table" and (contract--[[# as TTable]]).Name then
		return "{*" .. ((contract--[[# as TTable]]).Name--[[# as TBaseType]]):GetData() .. "*}"
	end

	if self.Name then return "{*" .. (self.Name:GetData()--[[# as any]]) .. "*}" end

	visited = visited or {}

	if visited[self] then return (visited[self]--[[# as any]]) end

	visited[self] = "*circular*"
	local data = self.Data
	local entries = {}

	for i = 1, #data do
		table.insert(entries, data[i].key:GetHash(visited) .. "=" .. data[i].val:GetHash(visited))
	end

	table_sort(entries)
	visited[self] = "{" .. table.concat(entries, ",") .. "}"
	return visited[self]
end

local level = 0

function META:__tostring()--[[#: string]]
	local self = self--[[# as any]]

	if self.suppress then return "current_table" end

	self.suppress = true

	do
		local contract = self:GetContract()

		if contract and contract.Type == "table" and (contract--[[# as TTable]]).Name then -- never called
			self.suppress = false
			return tostring(((contract--[[# as TTable]]).Name--[[# as TBaseType]]):GetData())
		end
	end

	if self.Name then
		self.suppress = false
		return tostring(self.Name:GetData())
	end

	local meta = self:GetMetaTable()

	if meta and meta.Type == "table" then
		local func = (meta--[[# as any]]):Get(ConstString("__tostring"))

		if func then
			local analyzer = context:GetCurrentAnalyzer()

			if analyzer then
				local str = (
					analyzer
				--[[# as any]]):GetFirstValue((analyzer--[[# as any]]):Call(func, Tuple({self})))

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

	if #self.Data <= 1 then indent = " " end

	local contract = self:GetContract()

	if contract and contract.Type == "table" and contract ~= self then
		local contract_data = (contract--[[# as any]]):GetData()
		local contract_len = #contract_data

		for i = 1, contract_len do
			local keyval = assert(contract_data[i])
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
		local data = self.Data
		local len = #data

		for i = 1, len do
			local keyval = assert(data[i])
			local key, val = tostring(keyval.key), tostring(keyval.val)
			s[i] = indent .. "[" .. key .. "]" .. " = " .. val
		end
	end

	level = level - 1
	self.suppress = false

	if #self.Data <= 1 then return "{" .. table.concat(s, ",") .. " }" end

	return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function META:GetArrayLength()--[[#: TBaseType]]
	if #self.Data == 0 then
		local contract = self:GetContract()

		if contract and contract ~= self and contract.Type == "table" then
			return (contract--[[# as TTable]]):GetArrayLength()
		end
	end

	local len = 0
	local data = self.Data
	local data_len = #data

	for i = 1, data_len do
		local kv = data[i]

		if kv.key:IsNumeric() then
			if kv.key:IsLiteral() then
				-- TODO: not very accurate
				if kv.key.Type == "range" then return kv.key:Copy() end

				if len + 1 == (kv.key--[[# as any]]):GetData() then
					len = (kv.key--[[# as any]]):GetData()
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

function META:FollowsContract(contract--[[#: TTable]])--[[#: boolean, string | nil]]
	if self.suppress then return true end

	if self:GetContract() == contract then return true end

	if not self.Data[1] and contract:CanBeEmpty() then return true end

	for _, keyval in ipairs(contract:GetData()) do
		local required_key = keyval.key

		if required_key:IsLiteral() then
			if not keyval.val:IsNil() then
				local res, err = self:FindKeyValExact(required_key)

				if not res and self:GetMetaTable() and self:GetMetaTable().Type == "table" then
					res, err = (self:GetMetaTable()--[[# as TTable]]):FindKeyValExact(required_key)
				end

				if not res then return res, err end

				local ok, err = (res--[[# as any]]).val:IsSubsetOf(keyval.val)

				if not ok then
					return false,
					error_messages.because(error_messages.table_key(error_messages.subset((res--[[# as any]]).key, keyval.key)), err)
				end
			end
		else
			local found_anything = false

			for _, keyval2 in ipairs(self.Data) do
				if keyval2.key:IsSubsetOf(required_key) then
					local old = self.suppress
					self.suppress = true
					local ok, err = keyval2.val:IsSubsetOf(keyval.val)
					self.suppress = old
					found_anything = true

					if not ok then
						return false,
						error_messages.because(error_messages.table_key(error_messages.subset(keyval2.key, keyval.key)), err)
					end
				end
			end

			if not found_anything then
				return false, error_messages.table_index(self, required_key)
			end
		end
	end

	local data = self.Data
	local len = #data

	for i = 1, len do
		local keyval = data[i]

		if not keyval.val:IsNil() then
			local res, err = contract:FindKeyValExact(keyval.key)

			-- it's ok if the key is not found, as we're doing structural checking
			if res then
				-- if it is found, we make sure its type matches
				local ok, err = keyval.val:IsSubsetOf((res--[[# as any]]).val)

				if not ok then
					return false,
					error_messages.because(error_messages.table_value(error_messages.subset((res--[[# as any]]).val, keyval.val)), err)
				end
			end
		end
	end

	return true
end

function META:CanBeEmpty()--[[#: boolean]]
	local data = self.Data
	local len = #data

	for i = 1, len do
		if not data[i].val:CanBeNil() then return false end
	end

	return true
end

function META:IsEmpty()--[[#: boolean]]
	local contract = self:GetContract()

	if contract and contract ~= self and contract.Type == "table" then
		return (contract--[[# as TTable]]):IsEmpty()
	end

	return not self.Data[1]
end

function META.IsSubsetOf(a--[[#: TTable]], b--[[#: TBaseType]])--[[#: boolean, any | nil]]
	return shared.IsSubsetOf(a, b)
end

function META:ContainsAllKeysIn(contract--[[#: TTable]])
	for _, keyval in ipairs(contract:GetData()) do
		if keyval.key:IsLiteral() then
			local ok, err = self:FindKeyValExact(keyval.key)

			if not ok then
				if keyval.val:CanBeNil() then return true end

				return false,
				error_messages.because(error_messages.key_missing_contract(keyval.key, contract), err)
			end
		end
	end

	return true
end

local function get_hash(key--[[#: TBaseType]])
	if key.Type ~= "table" and key.Type ~= "function" and key.Type ~= "tuple" then
		return key:GetHash()
	end
end

local function write_cache(
	self--[[#: TTable]],
	key--[[#: TBaseType]],
	val--[[#: {key = TBaseType, val = TBaseType} | nil]]
)
	local hash = get_hash(key)

	if hash then self.literal_data_cache[hash] = val end
end

local function read_cache(self--[[#: TTable]], key--[[#: TBaseType]])
	local hash = get_hash(key)

	if hash then
		local val = self.literal_data_cache[hash]

		if val then return val end

		return false, error_messages.table_index(self, key)
	end

	return nil
end

local function read_cache_no_error(self--[[#: TTable]], key--[[#: TBaseType]])
	local hash = get_hash(key)

	if hash then return self.literal_data_cache[hash] end

	return nil
end

function META:AddKey(
	keyval--[[#: {key = TBaseType, val = TBaseType} | false | nil]],
	key--[[#: TBaseType]],
	val--[[#: TBaseType]]
)
	if not keyval then
		local keyval = {key = key, val = val}
		table.insert(self.Data--[[# as any]], keyval)
		write_cache(self, key, keyval)
	else
		if keyval.key:IsLiteral() and keyval.key:Equal(key) then
			(keyval--[[# as any]]).val = val
		else
			(keyval--[[# as any]]).val = Union({keyval.val, val})
		end
	end
end

function META:RemoveRedundantNilValues()
	for i = #self.Data, 1, -1 do
		local keyval = assert(self.Data[i])

		if
			keyval.key.Type == "number" and
			keyval.val.Type == "symbol" and
			keyval.val:IsNil()
		then
			table.remove(self.Data--[[# as any]], i)
			write_cache(self, keyval.key, nil)
		else
			break
		end
	end
end

function META:Delete(key--[[#: TBaseType]])--[[#: boolean]]
	for i = #self.Data, 1, -1 do
		local keyval = self.Data[i]

		if keyval and key:Equal(keyval.key) then
			table.remove(self.Data, i)
			write_cache(self, keyval.key, nil)
		end
	end

	return true
end

do
	function META:Insert(val--[[#: TBaseType]])
		self.size = (self.size--[[# as number]]) or 1
		self:Set(LNumber(self.size--[[# as number]]), val)
		self.size = (self.size--[[# as number]]) + 1
	end

	function META:Concat(separator--[[#: TBaseType | nil]])--[[#: TBaseType | string]]
		if not self:IsLiteral() then return String() end

		if
			separator and
			(
				(
					separator.Type ~= "string" or
					not separator:IsLiteral()
				)
				and
				(
					separator.Type ~= "symbol" or
					(
						separator
					--[[# as any]]):IsBoolean()
				)
			)
		then
			return String()
		end

		local out = {}

		for i, keyval in ipairs(self.Data) do
			if not keyval.val:IsLiteral() or keyval.val.Type == "union" then
				return String()
			end

			out[i] = (keyval.val--[[# as any]]):GetData()
		end

		return table.concat(out, separator and (separator--[[# as any]]):GetData() or nil)
	end

	function META:Remove(index--[[#: TBaseType]])--[[#: TBaseType | false]]
		local index_num = (index--[[# as any]]):GetData()
		local removed_val--[[#: TBaseType | nil]] = nil
		local found_index--[[#: number | nil]] = nil

		for i = #self.Data, 1, -1 do
			local keyval = self.Data[i]

			if keyval and keyval.key.Type == "number" and keyval.key:IsLiteral() then
				local key_num = (keyval.key--[[# as any]]):GetData()

				if key_num == index_num then
					removed_val = keyval.val
					found_index = i
					table.remove(self.Data, i)
					write_cache(self, keyval.key, nil)

					break
				end
			end
		end

		if not found_index then
			return false, error_messages.table_index(self, index)
		end

		for i, keyval in ipairs(self.Data) do
			if keyval and keyval.key.Type == "number" and keyval.key:IsLiteral() then
				local key_num = (keyval.key--[[# as any]]):GetData()

				if key_num > (index_num--[[# as number]]) then
					write_cache(self, keyval.key, nil)
					local new_key = LNumber(key_num - 1)
					keyval.key = new_key
					write_cache(self, new_key, keyval)
				end
			end
		end

		if self.size and (self.size--[[# as number]]) > (index_num--[[# as number]]) then
			self.size = (self.size--[[# as number]]) - 1
		end

		return removed_val--[[# as TBaseType]]
	end
end

function META:GetValueUnion()--[[#: TBaseType]]
	local union = Union()

	for _, keyval in ipairs(self.Data) do
		union:AddType(keyval.val:Copy())
	end

	return union
end

function META:HasKey(key--[[#: TBaseType]])--[[#: boolean]]
	if key.Type == "deferred" then key = key:Unwrap() end

	if read_cache(self, key) then return true end

	for i, keyval in ipairs(self.Data) do
		if key:Equal(keyval.key) or key:IsSubsetOf(keyval.key) then return true end
	end

	return false
end

function META:FindKeyValExact(key--[[#: TBaseType]])--[[#: ({key = TBaseType, val = TBaseType} | false), (any | nil)]]
	if key.Type == "deferred" then key = key:Unwrap() end

	local keyval, reason = read_cache(self--[[# as any]], key)

	if keyval then return keyval--[[# as any]], reason end

	local reasons = {}

	for i, keyval in ipairs(self.Data--[[# as any]]) do
		if keyval then
			local ok, reason = (keyval--[[# as any]]).key:IsSubsetOf(key)

			if ok then return keyval--[[# as any]] end

			if i <= 20 then reasons[i] = reason end
		end
	end

	if not reasons[1] then reasons[1] = error_messages.table_index(self, key) end

	return false,
	error_messages.because(error_messages.table_index(self, key), reasons)
end

function META:FindKeyValWide(key--[[#: TBaseType]], reverse--[[#: boolean | nil]])--[[#: ({key = TBaseType, val = TBaseType} | false), (any | nil)]]
	if key.Type == "deferred" then key = key:Unwrap() end

	local keyval = read_cache(self--[[# as any]], key)

	if keyval then return keyval--[[# as any]] end

	local reasons--[[#: List<|any|>]] = {}
	local data = self.Data--[[# as any]]
	local len = #data

	for i = 1, len do
		local keyval = data[i]

		if keyval then
			if key:Equal(keyval.key) then return keyval--[[# as any]] end

			local ok, reason

			if reverse then
				ok, reason = keyval.key:IsSubsetOf(key)
			else
				ok, reason = key:IsSubsetOf(keyval.key)
			end

			if ok then return keyval--[[# as any]] end

			if i <= 20 then reasons[i] = reason end
		end
	end

	if #reasons > 20 then reasons = {error_messages.table_index(self, key)} end

	if not reasons[1] then
		reasons[1] = error_messages.because(error_messages.table_index(self, key), {"table is empty"})
	end

	return false,
	error_messages.because(error_messages.table_index(self, key), reasons)
end

function META:Set(key--[[#: TBaseType]], val--[[#: TBaseType | nil]], no_delete--[[#: boolean | nil]])--[[#: boolean, (any | nil)]]
	return shared.Set(self, key, val, no_delete)
end

function META:SetExplicit(key--[[#: TBaseType]], val--[[#: TBaseType]])
	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
		local lua_key = "Set" .. key:GetData():sub(2)
		assert(self[lua_key], lua_key .. " is not a function")(self, val)
		return true
	end

	if key.Type == "symbol" and key:IsNil() then
		return false, error_messages.table_key("is nil")
	end

	-- if the key exists, check if we can replace it and maybe the value
	self:AddKey(read_cache_no_error(self, key), key, val)
	return true
end

function META:Get(key--[[#: TBaseType]])--[[#: (TBaseType | false), (any | nil)]]
	return shared.Get(self, key)
end

function META:IsNumericallyIndexed()
	for _, keyval in ipairs(self.Data) do
		if not keyval.key:IsNumeric() then return false end -- TODO, check if there are holes?
	end

	return true
end

function META:CopyLiteralness(from, map)--[[#: TTable]]
	if from.Type ~= self.Type then return self end

	if self:Equal(from) then return self end

	map = map or {}

	if map[from] then return map[from] end

	local copy = self:Copy()
	map[from] = copy

	for _, keyval_from in ipairs(from:GetData()) do
		local keyval = copy:FindKeyValExact(keyval_from.key)

		if keyval then
			keyval.key = (keyval.key--[[# as any]]):CopyLiteralness(keyval_from.key, map)
			keyval.val = (keyval.val--[[# as any]]):CopyLiteralness(keyval_from.val, map)
		end
	end

	return copy--[[# as TTable]]
end

function META:CopyLiteralness2(from)
	if from.Type ~= self.Type then return self end

	if self:Equal(from) then return self end

	local ref_map = {[from] = self}

	for _, keyval_from in ipairs(from:GetData()) do
		local keyval, reason = self:FindKeyValExact(keyval_from.key)

		if keyval then
			self:Delete(keyval.key)
			self:AddKey(nil, keyval_from.key:Copy(ref_map), keyval_from.val:Copy(ref_map))
		end
	end

	return self
end

function META:CoerceUntypedFunctions(from--[[#: TTable]])
	for _, kv in ipairs(self.Data) do
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
		local k = copy_val(keyval.key, map, copy_tables)--[[# as TBaseType]]
		local v = copy_val(keyval.val, map, copy_tables)--[[# as TBaseType]]
		local d = copy.Data--[[# as any]]
		d[i] = {key = k, val = v}--[[# as any]]
		write_cache(copy, k, d[i])
	end

	copy:CopyInternalsFrom(self)
	copy.MetaTable = self.MetaTable --copy_val(self.MetaTable, map, copy_tables)
	copy.Contract = self:GetContract() --copy_val(self.Contract, map, copy_tables)
	copy:SetAnalyzerEnvironment(self:GetAnalyzerEnvironment())
	copy.mutations = self.mutations or false
	copy:SetCreationScope(self:GetCreationScope())
	copy.UniqueID = self.UniqueID
	copy:SetName(self:GetName())
	copy:SetTypeOverride(self:GetTypeOverride())

	if self:GetSelfArgument() then
		copy:SetSelfArgument(self:GetSelfArgument():Copy(map, copy_tables))
	end

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

	if
		contract and
		contract ~= self and
		not (
			contract
		--[[# as TTable]]):HasLiteralKeys()
	then
		return false
	end

	for _, v in ipairs(self.Data) do
		if
			v.val ~= self and
			v.key ~= self and
			v.val.Type ~= "function" and
			v.key.Type ~= "function"
		then
			local old = self.suppress
			self.suppress = true
			local ok, reason = v.key:IsLiteral()
			self.suppress = old

			if not ok then return false end
		end
	end

	return true
end

function META:IsLiteral()
	if self.suppress then return true end

	if self:GetContract() then return false end

	for _, v in ipairs(self.Data) do
		if
			v.val ~= self and
			v.key ~= self and
			v.val.Type ~= "function" and
			v.key.Type ~= "function"
		then
			local old = self.suppress
			self.suppress = true
			local ok, reason = v.key:IsLiteral()
			self.suppress = old

			if not ok then return false end

			local old = self.suppress
			self.suppress = true
			local ok, reason = v.val:IsLiteral()
			self.suppress = old

			if not ok then return false end
		end
	end

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
	return shared.LogicalComparison(l, r, op, env)
end

do
	local function initialize_table_mutation_tracker(tbl, scope, key, hash)
		tbl.mutations = tbl.mutations or {}
		tbl.mutationsi = tbl.mutationsi or {}

		if not tbl.mutations[hash] then
			tbl.mutations[hash] = {}
			table.insert(tbl.mutationsi, tbl.mutations[hash])
		end

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
			return false, error_messages.too_many_mutations()
		end

		table.insert(self.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking, key = key})

		if from_tracking then scope:AddTrackedObject(self) end

		return true
	end

	function META:ClearMutations()
		self.mutations = false
		self.mutationsi = false
	end

	function META:ClearTrackedMutations()
		if not self:HasMutations() then return end

		for _, mutations in ipairs(self:GetMutationsi()) do
			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if mut.from_tracking then table.remove(mutations, i) end
			end
		end
	end

	function META:SetMutations(tbl)
		self.mutations = tbl
	end

	function META:GetMutations()
		return self.mutations
	end

	function META:GetMutationsi()
		return self.mutationsi
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

		for _, mutations in ipairs(self.mutationsi) do
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
			return false, error_messages.unique_type_type_mismatch(a, b)
		end

		if a.UniqueID ~= b.UniqueID then
			return false, error_messages.unique_type_mismatch(a, b)
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
			TruthyFalsy = "truthy",
			Data = {},
			CreationScope = false,
			AnalyzerEnvironment = false,
			Upvalue = false,
			UniqueID = false,
			Name = false,
			Self = false,
			literal_data_cache = {},
			Contracts = {},
			TypeOverride = false,
			suppress = false,
			mutations = false,
			potential_self = false,
			string_metatable = false,
			size = false,
			disabled_unique_id = false,
			co_func = false,
			func = false,
			ReferenceId = false,
			MetaTable = false,
			Contract = false,
			MutationLimit = 100,
			mutationsi = false,
		}
	)
end

return {
	TTable = TTable,
	Table = META.New,
}