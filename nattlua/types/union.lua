local tostring = tostring
local setmetatable = _G.setmetatable
local table = _G.table
local ipairs = _G.ipairs
local Nil = require("nattlua.types.symbol").Nil
local type_errors = require("nattlua.types.error_messages")

--[[#local type { TNumber } = require("nattlua.types.number")]]

local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TUnion"]]
--[[#type TUnion = META.@Self]]
--[[#type TUnion.Data = List<|TBaseType|>]]
--[[#type TUnion.suppress = boolean]]
META.Type = "union"

function META:GetHash()
	return tostring(self)
end

function META.Equal(a--[[#: TUnion]], b--[[#: TBaseType]])
	if a.suppress then return true end

	if b.Type ~= "union" and #a.Data == 1 then return a.Data[1]:Equal(b) end

	if a.Type ~= b.Type then return false end

	if #a.Data ~= #b.Data then return false end

	for i = 1, #a.Data do
		local ok = false
		local a = a.Data[i]

		for i = 1, #b.Data do
			local b = b.Data[i]
			a.suppress = true
			ok = a:Equal(b)
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

function META:ShrinkToFunctionSignature()
	local Tuple = require("nattlua.types.tuple").Tuple
	local arg = Tuple({})
	local ret = Tuple({})

	for _, func in ipairs(self.Data) do
		if func.Type ~= "function" then return false end

		arg:Merge(func:GetInputSignature())
		ret:Merge(func:GetOutputSignature())
	end

	local Function = require("nattlua.types.function").Function
	return Function(arg, ret)
end

local sort = function(a, b)
	return a < b
end

function META:__tostring()
	if self.suppress then return "current_union" end

	local s = {}
	self.suppress = true

	for _, v in ipairs(self.Data) do
		table.insert(s, tostring(v))
	end

	if not s[1] then
		self.suppress = false
		return "|"
	end

	self.suppress = false
	table.sort(s, sort)
	return table.concat(s, " | ")
end

function META:AddType(e--[[#: TBaseType]])
	if e.Type == "union" then
		for _, v in ipairs(e.Data) do
			self:AddType(v)
		end

		return self
	end

	for _, v in ipairs(self.Data) do
		if v:Equal(e) then
			if
				e.Type ~= "function" or
				e:GetContract() or
				(
					e:GetFunctionBodyNode() and
					(
						e:GetFunctionBodyNode() == v:GetFunctionBodyNode()
					)
				)
			then
				return self
			end
		end
	end

	if e.Type == "string" or e.Type == "number" then
		local sup = e

		for i = #self.Data, 1, -1 do
			local sub = self.Data[i]--[[# as TBaseType]] -- TODO, prove that the for loop will always yield TBaseType?
			if sub.Type == sup.Type then
				if sub:IsSubsetOf(sup) then table.remove(self.Data, i) end
			end
		end
	end

	table.insert(self.Data, e)
	return self
end

function META:GetData()
	return self.Data
end

function META:GetLength()
	return #self.Data
end

function META:RemoveType(e--[[#: TBaseType]])
	if e.Type == "union" then
		for i, v in ipairs(e.Data) do
			self:RemoveType(v)
		end

		return self
	end

	for i, v in ipairs(self.Data) do
		if v:Equal(e) then
			table.remove(self.Data, i)

			break
		end
	end

	return self
end

function META:Clear()
	self.Data = {}
end

function META:HasTuples()
	for _, obj in ipairs(self.Data) do
		if obj.Type == "tuple" then return true end
	end

	return false
end

function META:GetAtIndex(i--[[#: number]])
	assert(type(i) == "number")

	if not self:HasTuples() then return self end

	local val
	local errors = {}

	for _, obj in ipairs(self.Data) do
		if obj.Type == "tuple" then
			local found, err = obj:Get(i)

			if found then
				if val then val = self.New({val, found}) else val = found end
			else
				if val then val = self.New({val, Nil()}) else val = Nil() end

				table.insert(errors, err)
			end
		else
			if val then
				-- a non tuple in the union would be treated as a tuple with the value repeated
				val = self.New({val, obj})
			elseif i == 1 then
				val = obj
			else
				val = Nil()
			end
		end
	end

	if not val then return false, errors end

	return val
end

function META:Get(key--[[#: TBaseType]])
	local errors = {}

	for _, obj in ipairs(self.Data) do
		local ok, reason = key:IsSubsetOf(obj)

		if ok then return obj end

		table.insert(errors, reason)
	end

	return type_errors.other(errors)
end

function META:IsEmpty()
	return self.Data[1] == nil
end

function META:GetTruthy()
	local copy = self:Copy()

	for _, obj in ipairs(self.Data) do
		if not obj:IsTruthy() then copy:RemoveType(obj) end
	end

	return copy
end

function META:GetFalsy()
	local copy = self:Copy()

	for _, obj in ipairs(self.Data) do
		if not obj:IsFalsy() then copy:RemoveType(obj) end
	end

	return copy
end

function META:IsType(typ--[[#: string]])
	assert(type(typ) == "string")

	if self:IsEmpty() then return false end

	for _, obj in ipairs(self.Data) do
		if obj.Type ~= typ then return false end
	end

	return true
end

function META:HasType(typ--[[#: string]])
	assert(type(typ) == "string")

	return self:GetType(typ) ~= false
end

function META:CanBeNil()
	for _, obj in ipairs(self.Data) do
		if obj.Type == "symbol" and obj:GetData() == nil then return true end
	end

	return false
end

function META:GetType(typ--[[#: string]])
	assert(type(typ) == "string")

	for _, obj in ipairs(self.Data) do
		if obj.Type == typ then return obj end
	end

	return false
end

function META:IsTargetSubsetOfChild(target--[[#: TBaseType]])
	local errors = {}

	for _, obj in ipairs(self:GetData()) do
		local ok, reason = target:IsSubsetOf(obj)

		if ok then return true end

		table.insert(errors, reason)
	end

	return type_errors.subset(target, self, errors)
end

function META.IsSubsetOf(A--[[#: TUnion]], B--[[#: TBaseType]])
	if B.Type ~= "union" then return A:IsSubsetOf(META.New({B})) end

	if B.Type == "tuple" then B = B:Get(1) end

	if not A.Data[1] then return type_errors.subset(A, B, "union is empty") end

	for _, a in ipairs(A.Data) do
		if a.Type == "any" then return true end
	end

	for _, a in ipairs(A.Data) do
		local b, reason = B:Get(a)

		if not b then return type_errors.missing(B, a, reason) end

		local ok, reason = a:IsSubsetOf(b)

		if not ok then return type_errors.subset(a, b, reason) end
	end

	return true
end

function META:Union(union--[[#: TUnion]])
	assert(union.Type == "union")
	local copy = self:Copy()

	for _, e in ipairs(union.Data) do
		copy:AddType(e)
	end

	return copy
end

function META:Copy(map--[[#: Map<|any, any|>]], copy_tables--[[#: nil | boolean]])
	map = map or {}
	local copy = META.New()
	map[self] = map[self] or copy

	for _, e in ipairs(self.Data) do
		if e.Type == "table" and not copy_tables then
			copy:AddType(e)
		else
			copy:AddType(e:Copy(map, copy_tables))
		end
	end

	copy:CopyInternalsFrom(self)
	return copy
end

function META:IsTruthy()
	for _, v in ipairs(self.Data) do
		if v:IsTruthy() then return true end
	end

	return false
end

function META:IsFalsy()
	for _, v in ipairs(self.Data) do
		if v:IsFalsy() then return true end
	end

	return false
end

function META:DisableFalsy()
	local found = {}

	for _, v in ipairs(self.Data) do
		if v:IsCertainlyFalse() then table.insert(found, v) end
	end

	for _, v in ipairs(found) do
		self:RemoveType(v)
	end

	self.falsy_disabled = found
	return self
end

function META:EnableFalsy()
	-- never called
	if not self.falsy_disabled then return end

	for _, v in ipairs(self.falsy_disabled) do
		self:AddType(v)
	end
end

function META:SetMax(val--[[#: TNumber]])
	-- never called
	local copy = self:Copy()

	for _, e in ipairs(copy.Data) do
		e:SetMax(val)
	end

	return copy
end

function META:IsLiteral()
	for _, obj in ipairs(self:GetData()) do
		if not obj:IsLiteral() then return false end
	end

	return true
end

function META:GetLargestNumber()
	-- never called
	if #self:GetData() == 0 then return type_errors.other({"union is empty"}) end

	local max = {}

	for _, obj in ipairs(self:GetData()) do
		if obj.Type ~= "number" then
			return type_errors.other({"union must contain numbers only", self})
		end

		if obj:IsLiteral() then table.insert(max, obj) else return obj end
	end

	table.sort(max, function(a, b)
		return a:GetData() > b:GetData()
	end)

	return max[1]
end

function META.New(data--[[#: nil | List<|TBaseType|>]])
	local self = setmetatable({
		Data = {},
		Falsy = false,
		Truthy = false,
		Literal = false,
	}, META)

	if data then for _, v in ipairs(data) do
		self:AddType(v)
	end end

	return self
end

return {
	Union = META.New,
	Nilable = function(typ)
		return META.New({typ, Nil()})
	end,
}
