--ANALYZE
local tostring = tostring
local table = _G.table
local math = math
local assert = assert
local debug = debug
local error = error
local setmetatable = _G.setmetatable
local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any
local type_errors = require("nattlua.types.error_messages")
local ipairs = _G.ipairs
local type = _G.type
local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
META.Type = "tuple"
--[[#type META.@Name = "TTuple"]]
--[[#type TTuple = META.@Self]]
META:GetSet("Data", nil--[[# as List<|TBaseType|>]])
META:GetSet("Unpackable", false--[[# as boolean]])

function META.Equal(a--[[#: TTuple]], b--[[#: TBaseType]], visited--[[#: Map<|TBaseType, boolean|>]])
	if a.Type ~= b.Type then return false, "types differ" end

	visited = visited or {}

	if visited[a] then return true, "circular reference detected" end

	if #a.Data ~= #b.Data then return false, "length mismatch" end

	local ok, reason = true, "all match"
	visited[a] = true

	for i = 1, #a.Data do
		ok, reason = a.Data[i]:Equal(b.Data[i], visited)

		if not ok then break end
	end

	if not ok then reason = reason or "unknown reason" end

	return ok, reason
end

function META:GetHash(visited)
	visited = visited or {}

	if visited[self] then return visited[self] end

	visited[self] = "*circular*"
	local types = {}

	for i, v in ipairs(self.Data) do
		types[i] = v:GetHash(visited)
	end

	visited[self] = table.concat(types, ",")
	return visited[self]
end

function META:__tostring()
	if self.suppress then return "current_tuple" end

	self.suppress = true
	local strings--[[#: List<|string|>]] = {}

	for i, v in ipairs(self:GetData()) do
		strings[i] = tostring(v)
	end

	if self.Remainder then table.insert(strings, tostring(self.Remainder)) end

	local s = "("

	if #strings == 1 and strings[1] then
		s = s .. strings[1] .. ","
	else
		s = s .. table.concat(strings, ", ")
	end

	s = s .. ")"

	if self.Repeat then s = s .. "*" .. tostring(self.Repeat) end

	self.suppress = false
	return s
end

function META:Merge(tup--[[#: TTuple]])
	local src = self:GetData()
	local len = tup:GetMinimumLength()

	if len == 0 and not tup:HasInfiniteValues() then
		len = tup:GetElementCount()
	end

	for i = 1, len do
		local a = self:GetWithNumber(i)
		local b = tup:GetWithNumber(i)

		if a and b then src[i] = Union({a, b}) elseif b then src[i] = b:Copy() end
	end

	self.Remainder = tup.Remainder or self.Remainder
	self.Repeat = tup.Repeat or self.Repeat
	return self
end

local function copy_val(val, map, copy_tables)
	if not val then return val end

	-- if it's already copied
	if map[val] then return map[val] end

	map[val] = val:Copy(map, copy_tables)
	return map[val]
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables)
	map = map or {}

	if map[self] then return map[self] end

	local copy = META.New({})
	map[self] = copy

	for i, v in ipairs(self:GetData()) do
		copy.Data[i] = copy_val(v, map, copy_tables)
	end

	copy.Repeat = self.Repeat
	copy.Remainder = copy_val(self.Remainder, map, copy_tables)
	copy.Unpackable = self.Unpackable
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(a--[[#: TTuple]], b--[[#: TBaseType]], max_length--[[#: nil | number]])
	if a == b then return true end

	if a.suppress then return true end

	if a.Remainder then
		local t = a:GetWithNumber(1)

		if t and t.Type == "any" and #a:GetData() == 0 then return true end
	end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

	do
		local t = a:GetWithNumber(1)

		if t and t.Type == "any" and b.Type == "tuple" and b:IsEmpty() then
			return true
		end
	end

	if b.Type == "any" then return true end

	if b.Type == "table" then
		if not b:IsNumericallyIndexed() then
			return false, type_errors.numerically_indexed(b)
		end
	end

	if b.Type ~= "tuple" then return false, type_errors.subset(a, b) end

	max_length = max_length or math.max(a:GetMinimumLength(), b:GetMinimumLength())

	for i = 1, max_length do
		local a_val, err = a:GetWithNumber(i)

		if not a_val then return false, type_errors.subset(a, b, err) end

		local b_val, err = b:GetWithNumber(i)

		if not b_val and a_val.Type == "any" then break end

		if not b_val then
			return false, type_errors.because(type_errors.table_index(b, i), err)
		end

		a.suppress = true
		local ok, reason = a_val:IsSubsetOf(b_val)
		a.suppress = false

		if not ok then
			return false, type_errors.because(type_errors.subset(a_val, b_val), reason)
		end
	end

	return true
end

function META.IsSubsetOfTupleWithoutExpansion(a--[[#: TTuple]], b--[[#: TBaseType]])
	for i, a_val in ipairs(a:GetData()) do
		local b_val, err = b:GetWithoutExpansion(i)

		if not b_val then return b_val, err, a_val, "nil", i end

		local ok, err = a_val:IsSubsetOf(b_val)

		if not ok then return ok, err, a_val, b_val, i end
	end

	return true
end

function META.IsSubsetOfTupleAtIndexWithoutExpansion(a--[[#: TTuple]], b--[[#: TTuple]], i--[[#: number]])
	local a_val = assert(a:GetData()[i])
	local b_val, err = b:GetWithoutExpansion(i)

	if not b_val then return false, err, a_val, Nil(), i end

	local ok, err = a_val:IsSubsetOf(b_val)

	if not ok then return false, err, a_val, b_val or Nil(), i end

	return true
end

function META.IsSubsetOfTupleAtIndex(a--[[#: TTuple]], b--[[#: TTuple]], i--[[#: number]])
	local a_val, a_err = a:GetWithNumber(i)
	local b_val, b_err = b:GetWithNumber(i)

	if a_val and a_val.Type == "union" then
		a_val, a_err = a_val:GetAtTupleIndex(1)
	end

	if b_val and b_val.Type == "union" then
		b_val, b_err = b_val:GetAtTupleIndex(1)
	end

	if not a_val then
		if b_val and b_val.Type == "any" then
			a_val = Any()
		else
			return false, a_err, a_val or Nil(), b_val or Nil(), i
		end
	end

	if not b_val then return false, b_err, a_val or Nil(), b_val or Nil(), i end

	if b_val.Type == "tuple" then
		b_val, b_err = b_val:GetWithNumber(1)

		if not b_val then return false, b_err, a_val or Nil(), b_val or Nil(), i end
	end

	a_val = a_val or Nil()
	b_val = b_val or Nil()
	local ok, reason = a_val:IsSubsetOf(b_val)

	if not ok then return false, reason, a_val, b_val or Nil(), i end

	return true
end

function META.IsSubsetOfTuple(a--[[#: TTuple]], b--[[#: TTuple]])
	if a:Equal(b) then return true end

	for i = 1, math.max(a:GetMinimumLength2(), b:GetMinimumLength2()) do
		local ok, reason, a_val, b_val, i = a.IsSubsetOfTupleAtIndex(a, b, i)

		if not ok then return ok, reason, a_val, b_val, i end
	end

	return true
end

function META.SubsetOrFallbackWithTuple(a--[[#: TTuple]], b--[[#: TTuple]])
	if a:Equal(b) then return a end

	local errors = {}

	for i = 1, math.max(a:GetMinimumLength2(), b:GetMinimumLength2()) do
		local ok, reason, a_val, b_val, offset = a.IsSubsetOfTupleAtIndex(a, b, i)

		if not ok then
			if not errors[1] then a = a:Copy() end

			a:Set(i, b_val)
			table.insert(errors, {reason, a_val, b_val, offset})
		end
	end

	return a, errors
end

function META.SubsetWithoutExpansionOrFallbackWithTuple(a--[[#: TTuple]], b--[[#: TTuple]])
	if a:Equal(b) then return a end

	local errors = {}

	for i, a_val in ipairs(a:GetData()) do
		local ok, reason, a_val, b_val, offset = a.IsSubsetOfTupleAtIndexWithoutExpansion(a, b, i)

		if not ok then
			if not errors[1] then a = a:Copy() end

			a:Set(i, b_val)
			table.insert(errors, {reason, a_val, b_val, offset})
		end
	end

	return a, errors
end

function META:HasTuples()
	for _, v in ipairs(self.Data) do
		if v.Type == "tuple" then return true end
	end

	if self.Remainder and self.Remainder.Type == "tuple" then return true end

	return false
end

function META:GetUnpackedElementCount()--[[#: number]]
	if false--[[# as true]] then
		-- TODO: recursion
		return nil--[[# as number]]
	end

	local len = 0

	for i, v in ipairs(self:GetData()) do
		if v.Type == "tuple" then
			len = len + v:GetUnpackedElementCount()
		elseif v.Type == "union" then
			local length = 0

			for i, v in ipairs(v:GetData()) do
				if v.Type == "tuple" then
					length = math.max(length, v:GetUnpackedElementCount())
				else
					length = math.max(length, 1)
				end
			end

			len = len + length
		else
			len = len + 1
		end
	end

	local remainder = self.Remainder and self.Remainder:GetUnpackedElementCount() or 0
	local rep = self.Repeat or 1
	return (len + remainder) * rep
end

function META:GetTupleLength()
	local len = self:GetUnpackedElementCount()

	for _, obj in ipairs(self.Data) do
		if obj.Type == "union" or obj.Type == "tuple" then
			len = math.max(len, obj:GetTupleLength())
		else
			len = math.max(len, 1)
		end
	end

	return len
end

function META:IsInfinite()
	return self.Remainder and self.Remainder.Repeat == math.huge
end

function META:GetAtTupleIndex(i)
	if i > self:GetTupleLength() then return nil end

	local obj = self:GetWithNumber(i)

	if obj then
		if obj.Type == "union" then
			return obj:GetAtTupleIndexUnion(i)
		elseif obj.Type == "tuple" then
			if obj:IsInfinite() then return obj, true end

			return obj:GetWithNumber(i)
		end
	end

	return obj
end

function META:GetWithNumber(i--[[#: number]])
	local val = self:GetData()[i]

	if not val and self.Repeat and i <= (#self:GetData() * self.Repeat) then
		return self:GetData()[((i - 1) % #self:GetData()) + 1]
	end

	if not val and self.Remainder then
		return self.Remainder:GetWithNumber(i - #self:GetData())
	end

	if not val then
		local last = self:GetData()[#self:GetData()]

		if last then
			if last.Type == "tuple" and (last.Repeat or last.Remainder) then
				return last:GetWithNumber(i)
			end

			if last.Type == "tuple" and last.Repeat == math.huge then return last end

			if last.Type == "union" and last:HasTuples() then
				local i = i - #self:GetData() + 1
				local found = Union()

				for _, v in ipairs(last:GetData()) do
					if v.Type == "tuple" then
						local obj = v:GetWithNumber(i)

						if obj then found:AddType(obj) end
					elseif v.Type == "union" then
						if i == 1 then
							local obj = v:GetAtTupleIndexUnion(i)

							if obj then found:AddType(obj) end
						end
					end
				end

				if found:GetCardinality() == 1 then return found:GetData()[1] end

				return found
			end
		end
	end

	if not val then return false, type_errors.missing_index(i) end

	return val
end

function META:Get(key--[[#: TBaseType]])
	if key.Type == "union" then
		local union = Union()

		for _, v in ipairs(key:GetData()) do
			if key.Type == "number" then
				local val = (self--[[# as any]]):Get(v)
				union:AddType(val)
			end
		end

		return union--[[# as TBaseType]]
	end

	if key.Type ~= "number" then
		return false, {"attempt to index tuple with", key.Type}
	end

	if key:IsLiteral() then return self:GetWithNumber(key:GetData()) end

	local union = Union()

	for i = 1, self:GetMinimumLength() do
		union:AddType(self:GetWithNumber(i))
	end

	return union
end

function META:IsLiteral()
	return false
end

function META:GetWithoutExpansion(i--[[#: number]])
	local val = self:GetData()[i]

	if not val then if self.Remainder then return self.Remainder end end

	if not val then return false, type_errors.missing_index(i) end

	return val
end

-- TODO, this should really be SetWithNumber, and Set should take a number object
function META:Set(i--[[#: number]], val--[[#: TBaseType]])
	if type(i) == "table" then
		if i.Type ~= "number" then return false, "expected number" end

		i = i:GetData()
	end

	if val.Type == "tuple" and val:HasOneValue() then
		val = val:GetWithNumber(1)
	end

	self.Data[i] = val

	if i > 32 then error("tuple too long", 2) end

	return true
end

function META:IsEmpty()
	return self:GetElementCount() == 0
end

function META:HasInfiniteValues()
	return self:GetElementCount() == math.huge
end

function META:HasOneValue()
	return self:GetElementCount() == 1
end

function META:IsTruthy()
	local obj = self:GetWithNumber(1)

	if obj then return obj:IsTruthy() end

	return false
end

function META:IsFalsy()
	local obj = self:GetWithNumber(1)

	if obj then return obj:IsFalsy() end

	return false
end

function META:GetElementCount()--[[#: number]]
	if false--[[# as true]] then
		-- TODO: recursion
		return nil--[[# as number]]
	end

	local remainder = self.Remainder and self.Remainder:GetElementCount() or 0
	local rep = self.Repeat or 1
	return (#self:GetData() + remainder) * rep
end

function META:GetMinimumLength2()
	if self.Repeat == math.huge or self.Repeat == 0 then return 0 end

	local len = #self:GetData()
	local found_nil--[[#: boolean]] = false

	for i = #self:GetData(), 1, -1 do
		local obj = self:GetData()[i]--[[# as TBaseType]]

		if not obj:IsNil() then return len else len = len - 1 end
	end

	return len
end

function META:GetMinimumLength()
	if self.Repeat == math.huge or self.Repeat == 0 then return 0 end

	local len = #self:GetData()
	local found_nil--[[#: boolean]] = false

	for i = #self:GetData(), 1, -1 do
		local obj = self:GetData()[i]--[[# as TBaseType]]

		if
			(
				obj.Type == "union" and
				obj:IsNil()
			) or
			(
				obj.Type == "symbol" and
				obj:IsNil()
			)
		then
			found_nil = true
			len = i - 1
		elseif found_nil then
			len = i

			break
		end
	end

	return len
end

function META:GetSafeLength(arguments--[[#: TTuple | nil]])
	if arguments then
		local len = self:GetElementCount()
		local arg_len = arguments:GetElementCount()

		if len == math.huge or arg_len == math.huge then
			if arg_len == math.huge then
				return math.max(self:GetMinimumLength(), arguments:GetMinimumLength())
			else
				return math.max(self:GetMinimumLength(), arguments:GetMinimumLength(), arg_len)
			end
		end

		return len
	end

	local len = self:GetElementCount()

	if len == math.huge then return self:GetMinimumLength() end

	return len
end

function META:AddRemainder(obj--[[#: TBaseType]])
	self.Remainder = obj
	return self
end

function META:SetRepeat(amt--[[#: number]])
	assert(amt > 0)
	self.Repeat = amt
	return self
end

function META:ToTable(length--[[#: nil | number]])
	length = length or self:GetElementCount()
	length = math.min(length, self:GetElementCount())
	assert(length ~= math.huge, "length must be finite")

	if length == 1 then return {(self:GetWithNumber(1))} end

	local out = {}

	for i = 1, length do
		out[i] = self:GetWithNumber(i)
	end

	return out
end

function META:Unpack(length--[[#: nil | number]])
	return table.unpack(self:ToTable(length))
end

function META:ToTableWithoutExpansion()
	local tbl = {}

	for i = 1, #self.Data do
		tbl[i] = self.Data[i]
	end

	if self.Remainder then table.insert(tbl, self.Remainder) end

	return tbl
end

function META:Slice(start--[[#: number]], stop--[[#: number]])
	-- TODO: not accurate yet
	start = start or 1
	stop = stop or #self:GetData()
	local data = {}

	for i = start, stop do
		local val, err = self:GetWithNumber(i)

		if not val then return val, err end

		table.insert(data, val)
	end

	local copy = META.New(data)
	copy.Repeat = self.Repeat
	copy.Remainder = self.Remainder and self.Remainder:Copy() or false
	copy.Unpackable = self.Unpackable
	copy:CopyInternalsFrom(self)
	return copy
end

function META:GetFirstValue()
	if self.Remainder then return self.Remainder:GetFirstValue() end

	local first, err = self:GetWithNumber(1)

	if not first then return first, err end

	if first.Type == "tuple" then return first:GetFirstValue() end

	return first
end

function META:Concat(tup--[[#: TTuple]])
	local start = self:GetElementCount()

	for i, v in ipairs(tup:GetData()) do
		self:Set(start + i, v)
	end

	return self
end

function META:SetTable(data)
	self.Data = {}

	for i, v in ipairs(data) do
		if
			i == #data and
			v.Type == "tuple" and
			not (
				v
			--[[# as TTuple]]).Remainder and
			v ~= self
		then
			self:AddRemainder(v)
		else
			table.insert(self.Data, v--[[# as any]])
		end
	end
end

function META.New(data--[[#: nil | List<|TBaseType|>]])
	local self = setmetatable(
		{
			Type = "tuple",
			Data = {},
			Falsy = false,
			Truthy = false,
			ReferenceType = false,
			Unpackable = false,
			suppress = false,
			Remainder = false,
			Repeat = false,
			Upvalue = false,
			Parent = false,
			Contract = false,
		},
		META
	)

	if data then self:SetTable(data) end

	return self
end

return {
	Tuple = META.New,
	VarArg = function(t--[[#: TBaseType]])
		local self = META.New({t})
		self:SetRepeat(math.huge)
		return self
	end,
	NormalizeTuples = function(types--[[#: List<|TBaseType|>]])
		local arguments

		if #types == 1 and types[1] and types[1].Type == "tuple" then
			arguments = types[1]
		else
			local temp = {}

			for i, v in ipairs(types) do
				if v.Type == "tuple" then
					if i == #types then
						table.insert(temp, v)
					else
						local obj = v:GetWithNumber(1)

						if obj then table.insert(temp, obj) end
					end
				else
					table.insert(temp, v)
				end
			end

			local old_temp = temp
			arguments = META.New(temp)
			local temp = {}

			for i = 1, 128 do
				local v, is_inf = arguments:GetAtTupleIndex(i)

				if v and v.Type == "tuple" or is_inf then
					-- inf tuple
					temp[i] = v

					break
				end

				if not v then break end

				temp[i] = v
			end

			arguments = META.New(temp)
		end

		return arguments
	end,
}
