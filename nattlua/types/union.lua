--ANALYZE
local tostring = tostring
local setmetatable = _G.setmetatable
local table = _G.table
local assert = _G.assert
local type = _G.type
local ipairs = _G.ipairs
local Nil = require("nattlua.types.symbol").Nil
local True = require("nattlua.types.symbol").True
local False = require("nattlua.types.symbol").False
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

	if b.Type ~= "union" and #a.Data == 1 and a.Data[1] then
		return a.Data[1]:Equal(b)
	end

	if a.Type ~= b.Type then return false end

	local b = b--[[# as TUnion]]

	if a:IsEmpty() and b:IsEmpty() then return true end

	if #a.Data ~= #b.Data then return false end

	for i = 1, #a.Data do
		local ok = false
		local a = a.Data[i]--[[# as TBaseType]]

		for i = 1, #b.Data do
			local b = b.Data[i]--[[# as TBaseType]]
			a.suppress = true--[[# as boolean]]
			ok = a:Equal(b)
			a.suppress = false--[[# as boolean]]

			if ok then break end
		end

		if not ok then
			a.suppress = false--[[# as boolean]]
			return false
		end
	end

	return true
end

local sort = function(a--[[#: string]], b--[[#: string]])
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

	if #s == 1 then return s[1] .. "|" end

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

	if not self:HasTuples() then
		if self:GetLength() == 1 then return self:GetData()[1] end

		return self
	end

	local val--[[#: any]]
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
				val = self.New({val--[[# as any]], obj})
			elseif i == 1 then
				val = obj
			else
				val = Nil()
			end
		end
	end

	if not val then return false, errors end

	if val.Type == "union" and val:GetLength() == 1 then return val:GetData()[1] end

	return val
end

function META:Get(key--[[#: TBaseType]])
	local errors = {}

	for _, obj in ipairs(self.Data) do
		local ok, reason = key:IsSubsetOf(obj)

		if ok then return obj end

		table.insert(errors, reason)
	end

	return false, errors
end

function META:IsEmpty()
	return self.Data[1] == nil
end

function META:RemoveCertainlyFalsy()
	local copy = self:Copy()

	for _, v in ipairs(self.Data) do
		if v:IsCertainlyFalse() then copy:RemoveType(v) end
	end

	return copy
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

function META:IsTypeExceptNil(typ--[[#: string]])
	assert(type(typ) == "string")

	if self:IsEmpty() then return false end

	for _, obj in ipairs(self.Data) do
		if obj.Type == "symbol" and obj.Data == nil then

		else
			if obj.Type ~= typ then return false end
		end
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

	return false, type_errors.subset(target, self, errors)
end

function META.IsSubsetOf(a--[[#: TUnion]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type ~= "union" then return a:IsSubsetOf(META.New({b})) end

	for _, a_val in ipairs(a.Data) do
		if a_val.Type == "any" then return true end
	end

	for _, b_val in ipairs(b.Data) do
		if b_val.Type == "any" then return true end
	end

	if a:IsEmpty() then
		return false, type_errors.because(type_errors.subset(a, b), "union is empty")
	end

	for _, a_val in ipairs(a.Data) do
		local b_val, reason = b:Get(a_val)

		if not b_val then
			return false, type_errors.because(type_errors.table_index(b, a_val), reason)
		end

		local ok, reason = a_val:IsSubsetOf(b_val)

		if not ok then
			return false, type_errors.because(type_errors.subset(a_val, b_val), reason)
		end
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

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables--[[#: nil | boolean]])
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

function META:IsLiteral()
	for _, obj in ipairs(self:GetData()) do
		if not obj:IsLiteral() then return false end
	end

	return true
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
			suppress = false,
		},
		META
	)

	if data then for _, v in ipairs(data) do
		self:AddType(v)
	end end

	return self
end

function META:Call(analyzer, input, call_node)
	if false--[[# as true]] then return end

	local Tuple = require("nattlua.types.tuple").Tuple

	if self:IsEmpty() then
		return false, type_errors.operation("call", nil, "union")
	end

	do
		-- make sure the union is callable, we pass the analyzer and 
		-- it will throw errors if the union contains something that is not callable
		-- however it will continue and just remove those values from the union
		local truthy_union = META.New()

		for _, v in ipairs(self.Data) do
			if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
				analyzer:ErrorAndCloneCurrentScope(type_errors.union_contains_non_callable(self, v), self--[[# as any]])
			else
				truthy_union:AddType(v)
			end
		end

		truthy_union:SetUpvalue(self:GetUpvalue())
		self = truthy_union
	end

	local is_overload = true

	for _, obj in ipairs(self.Data) do
		if obj.Type ~= "function" or obj:GetFunctionBodyNode() then
			is_overload = false

			break
		end
	end

	if is_overload then
		local errors = {}

		for _, obj in ipairs(self.Data) do
			if
				obj.Type == "function" and
				input:GetLength() < obj:GetInputSignature():GetMinimumLength()
			then
				table.insert(
					errors,
					{
						"invalid amount of arguments: ",
						input,
						" ~= ",
						obj:GetInputSignature(),
					}
				)
			else
				local res, reason = obj:Call(analyzer, input, call_node, true)

				if res then return res end

				table.insert(errors, reason)
			end
		end

		return false, errors
	end

	local new = META.New({})

	for _, obj in ipairs(self:GetData()) do
		local val = analyzer:Assert(obj:Call(analyzer, input, call_node, true))

		-- TODO
		if val.Type == "tuple" and val:GetLength() == 1 then
			val = val:Unpack(1)
		elseif val.Type == "union" and val:GetMinimumLength() == 1 then
			val = val:GetAtIndex(1)
		end

		new:AddType(val)
	end

	return Tuple({new--[[# as any]]})
end

function META:NewIndex(analyzer, key, val)
	-- local x: nil | {foo = true}
	-- log(x.foo) << error because nil cannot be indexed, to continue we have to remove nil from the union
	-- log(x.foo) << no error, because now x has no key nil
	local new_union = META.New()
	local truthy_union = META.New()
	local falsy_union = META.New()

	for _, v in ipairs(self:GetData()) do
		local ok, err = analyzer:NewIndexOperator(v, key, val)

		if not ok then
			analyzer:ErrorAndCloneCurrentScope(err or "invalid set error", self--[[# as any]])
			falsy_union:AddType(v)
		else
			truthy_union:AddType(v)
			new_union:AddType(v)
		end
	end

	truthy_union:SetUpvalue(self:GetUpvalue())
	falsy_union:SetUpvalue(self:GetUpvalue())
	return new_union
end

function META:Index(analyzer, key)
	local union = META.New({})

	for _, obj in ipairs(self.Data) do
		if obj.Type == "tuple" and obj:GetLength() == 1 then obj = obj:Get(1) end

		-- if we have a union with an empty table, don't do anything
		-- ie {[number] = string} | {}
		if obj.Type == "table" and obj:IsEmpty() then

		else
			local val, err = obj:Get(key)

			if not val then return val, err end

			union:AddType(val)
		end
	end

	return union
end

return {
	Union = META.New,
	Nilable = function(typ--[[: TBaseType]] )
		return META.New({typ, Nil()})
	end,
	Boolean = function()
		return META.New({True(), False()})
	end,
}