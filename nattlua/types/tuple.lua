local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")
local META = {}
META.Type = "tuple"
require("nattlua.types.base")(META)

function META.Equal(a, b)
	if a.Type ~= b.Type then return false end
	if a.suppress then return true end
	if #a.data ~= #b.data then return false end

	for i = 1, #a.data do
		a.suppress = true
		local ok = a.data[i]:Equal(b.data[i])
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
			src[i] = types.Union({a, b})
		else
			src[i] = b:Copy()
		end
	end

	self.Remainder = tup.Remainder or self.Remainder
	self.Repeat = tup.Repeat or self.Repeat
	return self
end

function META:SetReferenceId(id)
	for i = 1, #self:GetData() do
		self:Get(i):SetReferenceId(id)
	end

	return self
end

function META:Copy(map)
	map = map or {}
	local copy = types.Tuple({})
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
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A, B)
	if A == B then return true end
	if A.suppress then return true end
	if A.Remainder and A:Get(1).Type == "any" and #A:GetData() == 0 then return true end

	if B.Type == "union" then
		local errors = {}

		for _, tup in ipairs(B:GetData()) do
			A.suppress = true
			local ok, reason = A:IsSubsetOf(tup)
			A.suppress = false

			if ok then
				return true
			else
				table.insert(errors, reason)
			end
		end

		return type_errors.subset(A, B, errors)
	end

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

	for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
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

	if A:GetMinimumLength() < B:GetMinimumLength() then return false, "length differs" end
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
				a = types.Any()
			else
				return a, a_err, a, b, i
			end
		end

		if not b then return b, b_err, a, b, i end

		if b.Type == "tuple" then
			b = b:Get(1)
			if not b then break end
		end

		a = a or types.Nil()
		b = b or types.Nil()
		local ok, reason = a:IsSubsetOf(b)
		if not ok then return ok, reason, a, b, i end
	end

	return true
end

function META:Get(key)
	local real_key = key

	if type(key) == "table" and key.Type == "number" and key:IsLiteral() then
		key = key:GetData()
	end

	assert(type(key) == "number", "key must be a number, got " .. tostring(key))
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

	if not val then return type_errors.other("index " .. tostring(real_key) .. " does not exist") end
	return val
end

function META:Set(i, val)
	if val.Type == "tuple" and val:GetLength() == 1 then
		val = val:Get(1)
	end

	self.data[i] = val

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

		if obj.Type == "union" and obj:CanBeNil() then
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

function META:Initialize(data)
	self:SetData({})
	data = data or {}

	for i, v in ipairs(data) do
		if i == #data and v.Type == "tuple" and not v.Remainder then
			self:AddRemainder(v)
		else
			self:Set(i, v)
		end
	end

	return true
end

return META
