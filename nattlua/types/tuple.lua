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
local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TTuple"]]
--[[#type TTuple = META.@Self]]
--[[#type TTuple.Remainder = nil | TTuple]]
--[[#type TTuple.Repeat = nil | number]]
--[[#type TTuple.suppress = boolean]]
META:GetSet("Data", nil--[[# as List<|TBaseType|>]])
META.Type = "tuple"
META:GetSet("Unpackable", false--[[# as boolean]])

function META.Equal(a--[[#: TTuple]], b--[[#: TBaseType]])
	if a.Type ~= b.Type then return false end

	if a.suppress then return true end

	if #a.Data ~= #b.Data then return false end

	for i = 1, #a.Data do
		local val = a.Data[i]--[[# as TBaseType]]
		a.suppress = true
		local ok = val:Equal(b.Data[i])
		a.suppress = false

		if not ok then return false end
	end

	return true
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

	for i = 1, tup:GetMinimumLength() do
		local a = self:Get(i)
		local b = tup:Get(i)

		if a then src[i] = Union({a, b}) elseif b then src[i] = b:Copy() end
	end

	self.Remainder = tup.Remainder or self.Remainder
	self.Repeat = tup.Repeat or self.Repeat
	return self
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables--[[#: nil | boolean]])
	map = map or {}
	local copy = self.New({})
	map[self] = map[self] or copy

	for i, v in ipairs(self:GetData()) do
		v = map[v] or v:Copy(map, copy_tables)
		map[v] = map[v] or v
		copy:Set(i, v)
	end

	if self.Remainder then copy.Remainder = self.Remainder:Copy(nil, copy_tables) end

	copy.Repeat = self.Repeat
	copy.Unpackable = self.Unpackable
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A--[[#: TTuple]], B--[[#: TBaseType]], max_length--[[#: nil | number]])
	if A == B then return true end

	if A.suppress then return true end

	if A.Remainder then
		local t = A:Get(1)

		if t and t.Type == "any" and #A:GetData() == 0 then return true end
	end

	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

	do
		local t = A:Get(1)

		if t and t.Type == "any" and B.Type == "tuple" and B:GetLength() == 0 then
			return true
		end
	end

	if B.Type == "any" then return true end

	if B.Type == "table" then
		if not B:IsNumericallyIndexed() then
			return type_errors.numerically_indexed(B)
		end
	end

	if B.Type ~= "tuple" then return type_errors.type_mismatch(A, B) end

	max_length = max_length or math.max(A:GetMinimumLength(), B:GetMinimumLength())

	for i = 1, max_length do
		local a, err = A:Get(i)

		if not a then return type_errors.subset(A, B, err) end

		local b, err = B:Get(i)

		if not b and a.Type == "any" then break end

		if not b then return type_errors.missing(B, i, err) end

		A.suppress = true
		local ok, reason = a:IsSubsetOf(b)
		A.suppress = false

		if not ok then return type_errors.subset(a, b, reason) end
	end

	return true
end

function META.IsSubsetOfTupleWithoutExpansion(A--[[#: TTuple]], B--[[#: TBaseType]])
	for i, a in ipairs(A:GetData()) do
		local b = B:GetWithoutExpansion(i)
		local ok, err = a:IsSubsetOf(b)

		if ok then return ok, err, a, b, i end
	end

	return true
end

function META.IsSubsetOfTuple(A--[[#: TTuple]], B--[[#: TBaseType]])
	if A:Equal(B) then return true end

	for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
		local a, a_err = A:Get(i)
		local b, b_err = B:Get(i)

		if b and b.Type == "union" then b, b_err = b:GetAtIndex(i) end

		if not a then
			if b and b.Type == "any" then
				a = Any()
			else
				return a, a_err, a or Nil(), b, i
			end
		end

		if not b then return b, b_err, a or Nil(), b, i end

		if b.Type == "tuple" then
			b = b:Get(1)

			if not b then break end
		end

		a = a or Nil()
		b = b or Nil()
		local ok, reason = a:IsSubsetOf(b)

		if not ok then return ok, reason, a, b, i end
	end

	return true
end

function META:HasTuples()
	for _, v in ipairs(self.Data) do
		if v.Type == "tuple" then return true end
	end

	if self.Remainder and self.Remainder.Type == "tuple" then return true end

	return false
end

function META:GetWithNumber(i--[[#: number]])
	local val = self:GetData()[i]

	if not val and self.Repeat and i <= (#self:GetData() * self.Repeat) then
		return self:GetData()[((i - 1) % #self:GetData()) + 1]
	end

	if not val and self.Remainder then
		return self.Remainder:Get(i - #self:GetData())
	end

	if not val then
		local last = self:GetData()[#self:GetData()]

		if last and last.Type == "tuple" and (last.Repeat or last.Remainder) then
			return last:Get(i)
		end
	end

	if not val then
		return type_errors.other({"index ", tostring(i), " does not exist"})
	end

	return val
end

function META:Get(key--[[#: number | TBaseType]])
	if type(key) == "number" then return self:GetWithNumber(key) end

	assert(key.Type == "number")

	if key:IsLiteral() then return self:GetWithNumber(key:GetData()) end
end

function META:GetWithoutExpansion(i--[[#: number]])
	local val = self:GetData()[i]

	if not val then if self.Remainder then return self.Remainder end end

	if not val then return type_errors.other({"index ", i, " does not exist"}) end

	return val
end

function META:Set(i--[[#: number]], val--[[#: TBaseType]])
	if type(i) == "table" then
		i = i:GetData()
		return false, "expected number"
	end

	if val.Type == "tuple" and val:GetLength() == 1 then val = val:Get(1) end

	self.Data[i] = val

	if i > 32 then error("tuple too long", 2) end

	return true
end

function META:IsEmpty()
	-- never called
	return self:GetLength() == 0
end

function META:IsTruthy()
	local obj = self:Get(1)

	if obj then return obj:IsTruthy() end

	return false
end

function META:IsFalsy()
	local obj = self:Get(1)

	if obj then return obj:IsFalsy() end

	return false
end

function META:GetLength()--[[#: number]]
	if false--[[# as true]] then
		-- TODO: recursion
		return nil--[[# as number]]
	end

	if self.Remainder then return #self:GetData() + self.Remainder:GetLength() end

	if self.Repeat then return #self:GetData() * self.Repeat end

	return #self:GetData()
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
				obj:CanBeNil()
			) or
			(
				obj.Type == "symbol" and
				obj:GetData() == nil
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

function META:GetSafeLength(arguments--[[#: TTuple]])
	local len = self:GetLength()

	if len == math.huge or arguments:GetLength() == math.huge then
		return math.max(self:GetMinimumLength(), arguments:GetMinimumLength())
	end

	return len
end

function META:AddRemainder(obj--[[#: TBaseType]])
	self.Remainder = obj
	return self
end

function META:SetRepeat(amt--[[#: number]])
	self.Repeat = amt
	return self
end

function META:Unpack(length--[[#: nil | number]])
	length = length or self:GetLength()
	length = math.min(length, self:GetLength())
	assert(length ~= math.huge, "length must be finite")
	local out = {}
	local i = 1

	for _ = 1, length do
		out[i] = self:Get(i)
		i = i + 1
	end

	return table.unpack(out)
end

function META:UnpackWithoutExpansion()
	local tbl = {table.unpack(self.Data)}

	if self.Remainder then table.insert(tbl, self.Remainder) end

	return table.unpack(tbl)
end

function META:Slice(start--[[#: number]], stop--[[#: number]])
	-- TODO: not accurate yet
	start = start or 1
	stop = stop or #self:GetData()
	local copy = self:Copy()
	local data = {}

	for i = start, stop do
		table.insert(data, (self:GetData()--[[# as TBaseType]])[i])
	end

	copy:SetData(data)
	return copy
end

function META:GetFirstValue()
	if self.Remainder then return self.Remainder:GetFirstValue() end

	local first, err = self:Get(1)

	if not first then return first, err end

	if first.Type == "tuple" then return first:GetFirstValue() end

	return first
end

function META:Concat(tup--[[#: TTuple]])
	local start = self:GetLength()

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
			table.insert(self.Data, v)
		end
	end
end

function META.New(data--[[#: nil | List<|TBaseType|>]])
	local self = setmetatable(
		{
			Data = {},
			Falsy = false,
			Truthy = false,
			Literal = false,
			LiteralArgument = false,
			ReferenceArgument = false,
			Unpackable = false,
			suppress = false,
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
						local obj = v:Get(1)

						if obj then table.insert(temp, obj) end
					end
				else
					table.insert(temp, v)
				end
			end

			arguments = META.New(temp)
		end

		return arguments
	end,
}
