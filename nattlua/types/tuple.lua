local tostring = tostring
local table = require("table")
local math = math
local assert = assert
local print = print
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
META.Type = "tuple"
META:GetSet("Unpackable", false--[[# as boolean]])

function META.Equal(a, b)
	if a.Type ~= b.Type then return false end
	if a.suppress then return true end
	if #a.Data ~= #b.Data then return false end

	for i = 1, #a.Data do
		a.suppress = true
		local ok = a.Data[i]:Equal(b.Data[i])
		a.suppress = false
		if not ok then return false end
	end

	return true
end

function META:__tostring()
	if self.suppress then return "*self-tuple*" end
	self.suppress = true
	local s = {}

	for i, v in ipairs(self:GetData()) do
		s[i] = tostring(v)
	end

	if self.Remainder then
		table.insert(s, tostring(self.Remainder))
	end

	local s = "⦗" .. table.concat(s, ", ") .. "⦘"

	if self.Repeat then
		s = s .. "×" .. tostring(self.Repeat)
	end

	self.suppress = false
	return s
end

function META:Merge(tup)
	if tup.Type == "union" then
		for _, obj in ipairs(tup:GetData()) do
			self:Merge(obj)
		end

		return self
	end

	local src = self:GetData()

	for i = 1, tup:GetMinimumLength() do
		local a = self:Get(i)
		local b = tup:Get(i)

		if a then
			src[i] = Union({a, b})
		else
			src[i] = b:Copy()
		end
	end

	self.Remainder = tup.Remainder or self.Remainder
	self.Repeat = tup.Repeat or self.Repeat
	return self
end

function META:Copy(map)
	map = map or {}
	local copy = self.New({})
	map[self] = map[self] or copy

	for i, v in ipairs(self:GetData()) do
		v = map[v] or v:Copy(map)
		map[v] = map[v] or v
		copy:Set(i, v)
	end

	if self.Remainder then
		copy.Remainder = self.Remainder:Copy()
	end

	copy.Repeat = self.Repeat
	copy.Unpackable = self.Unpackable
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A, B, max_length)
	if A == B then return true end
	if A.suppress then return true end
	if A.Remainder and A:Get(1).Type == "any" and #A:GetData() == 0 then return true end
	if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end
	if
		A:Get(1) and
		A:Get(1).Type == "any" and
		B.Type == "tuple" and
		B:GetLength() == 0
	then
		return true
	end

	if B.Type == "any" then return true end

	if B.Type == "table" then
		if not B:IsNumericallyIndexed() then return type_errors.numerically_indexed(B) end
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

function META.IsSubsetOfTupleWithoutExpansion(A, B)
	for i, a in ipairs(A:GetData()) do
		local b = B:GetWithoutExpansion(i)
		local ok, err = a:IsSubsetOf(b)
		if ok then
			return ok, err, a,b,i
		end
	end
	return true
end

function META.IsSubsetOfTuple(A, B)
	if A:Equal(B) then return true end

	if A:GetLength() == math.huge and B:GetLength() == math.huge then
		for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
			local a = A:Get(i)
			local b = B:Get(i)
			local ok, err = a:IsSubsetOf(b)

			if not ok then
				local ok, err = type_errors.subset(a, b, err)
				return ok, err, a, b, i
			end
		end

		return true
	end

	for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
		local a, a_err = A:Get(i)
		local b, b_err = B:Get(i)

		if b and b.Type == "union" then
			b, b_err = b:GetAtIndex(i)
		end

		if not a then
			if b and b.Type == "any" then
				a = Any()
			else
				return a, a_err, a, b, i
			end
		end

		if not b then return b, b_err, a, b, i end

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
		if v.Type == "tuple" then
			return true
		end
	end
	if self.Remainder and self.Remainder.Type == "tuple" then
		return true
	end
	return false
end

function META:Get(key)
	local real_key = key

	if type(key) == "table" and key.Type == "number" and key:IsLiteral() then
		key = key:GetData()
	end

	if type(key) ~= "number" then
		print(real_key, "REAL_KEY")
		print(analyzer:DebugStateToString())
		error("key must be a number, got " .. tostring(key) .. debug.traceback())
	end

	local val = self:GetData()[key]
	if not val and self.Repeat and key <= (#self:GetData() * self.Repeat) then return self:GetData()[((key - 1) % #self:GetData()) + 1] end
	if not val and self.Remainder then return self.Remainder:Get(key - #self:GetData()) end

	if
		not val and
		self:GetData()[#self:GetData()] and
		(self:GetData()[#self:GetData()].Repeat or self:GetData()[#self:GetData()].Remainder)
	then
		return self:GetData()[#self:GetData()]:Get(key)
	end

	if not val then return type_errors.other({"index ", real_key, " does not exist"}) end
	return val
end

function META:GetWithoutExpansion(key)
	local val = self:GetData()[key]
	if not val then
		if self.Remainder then
			return self.Remainder
		end
	end
	if not val then return type_errors.other({"index ", key, " does not exist"}) end
	return val
end

function META:Set(i, val)
	if type(i) == "table" then
		i = i:GetData()
		return false, "expected number"
	end

	if val.Type == "tuple" and val:GetLength() == 1 then
		val = val:Get(1)
	end

	self.Data[i] = val

	if i > 32 then
		print(debug.traceback())
		error("tuple too long", 2)
	end

	return true
end

function META:IsConst()
	for _, obj in ipairs(self:GetData()) do
		if not obj:IsConst() then return false end
	end

	return true
end

function META:IsEmpty()
	return self:GetLength() == 0
end

function META:SetLength() 
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

function META:GetLength()
	if self.Remainder then return #self:GetData() + self.Remainder:GetLength() end
	if self.Repeat then return #self:GetData() * self.Repeat end
	return #self:GetData()
end

function META:GetMinimumLength()
	local len = #self:GetData()
	local found_nil = false

	for i = #self:GetData(), 1, -1 do
		local obj = self:GetData()[i]

		if (obj.Type == "union" and obj:CanBeNil()) or (obj.Type == "symbol" and obj:GetData() == nil) then
			found_nil = true
			len = i - 1
		elseif found_nil then
			len = i

			break
		end
	end

	return len
end

function META:GetSafeLength(arguments)
	local len = self:GetLength()
	if len == math.huge or arguments:GetLength() == math.huge then return math.max(self:GetMinimumLength(), arguments:GetMinimumLength()) end
	return len
end

function META:AddRemainder(obj)
	self.Remainder = obj
	return self
end

function META:SetRepeat(amt)
	self.Repeat = amt
	return self
end

function META:Unpack(length)
	length = length or self:GetLength()
	length = math.min(length, self:GetLength())
	assert(length ~= math.huge, "length must be finite")
	local out = {}
	local i = 1

	for _ = 1, length do
		out[i] = self:Get(i)

		if out[i] and out[i].Type == "tuple" then
			if i == length then
				for _, v in ipairs({out[i]:Unpack(out[i]:GetMinimumLength())}) do
					out[i] = v
					i = i + 1
				end
			else
				out[i] = out[i]:Get(1)
			end
		end

		i = i + 1
	end

	return table.unpack(out)
end

function META:UnpackWithoutExpansion()
	local tbl = {table.unpack(self.Data)}
	if self.Remainder then
		table.insert(tbl, self.Remainder)		
	end
	return table.unpack(tbl)
end

function META:Slice(start, stop)
    -- NOT ACCURATE YET

    start = start or 1
	stop = stop or #self:GetData()
	local copy = self:Copy()
	local data = {}

	for i = start, stop do
		table.insert(data, self:GetData()[i])
	end

	copy:SetData(data)
	return copy
end

function META:GetFirstValue()
	if self.Remainder then
		return self.Remainder:GetFirstValue()
	end
	return self:Get(1):GetFirstValue()
end

function META.New(data)
	local self = setmetatable({Data = {}}, META)

	if data then
		for i, v in ipairs(data) do
			if i == #data and v.Type == "tuple" and not v.Remainder then
				self:AddRemainder(v)
			else
				self.Data[i] = v
			end
		end
	end

	return self
end

return
	{
		Tuple = META.New,
		VarArg = function()
			local self = META.New({Any()})
			self:SetRepeat(math.huge)
			return self
		end,
		NormalizeTuples = function (types)
			local arguments

			if #types == 1 and types[1].Type == "tuple" then
				arguments = types[1]
			else
				local temp = {}

				for i, v in ipairs(types) do
					if v.Type == "tuple" then

						if i == #types then
							table.insert(temp, v)
						else
							local obj = v:Get(1)


							if obj then
								table.insert(temp, obj)
							end
						end
					else
						
						table.insert(temp, v)
					end
				end

				arguments = META.New(temp)
			end
			return arguments
		end
	}
