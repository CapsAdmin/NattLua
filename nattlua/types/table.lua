local types = require("nattlua.types.types")
local Union = require("nattlua.types.union").Union
local Number = require("nattlua.types.number").Number
local Tuple = require("nattlua.types.tuple").Tuple
local type_errors = require("nattlua.types.error_messages")
local table = require("table")
local ipairs = _G.ipairs
local tostring = _G.tostring
local META = dofile("nattlua/types/base.lua")
META.Type = "table"

function META:SetSelf(tbl)
	tbl:SetMetaTable(self)
	tbl.mutable = true
	tbl:SetContractSelf()
	self.Self = tbl
end

function META:SetReferenceId(ref)
	self.reference_id = ref
	return self
end

function META:GetReferenceId()
	return self.reference_id
end


function META:SetContractSelf()
	self:SetContract(self)

	for _, keyval in ipairs(self:GetData()) do
		if keyval.key.Type == "table" and not keyval.key:GetContract() then
			keyval.key:SetContractSelf()
		end

		if keyval.val.Type == "table" and not keyval.val:GetContract() then
			keyval.val:SetContractSelf()
		end
	end

	return true
end

function META:GetSelf()
	return self.Self
end

function META.Equal(a, b)
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
	local adata = a:GetContract() or a:GetData()
	local bdata = b:GetContract() or b:GetData()
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

function META:GetLuaType()
	return self.Type
end

function META:__tostring()
	if self.suppress then return "*self-table*" end
	self.suppress = true

	if self:GetContract() and self:GetContract().Name then -- never called
		self.suppress = nil
		return self:GetContract().Name:GetData()
	end

	if self.Name then
		self.suppress = nil
		return self.Name:GetData()
	end

	local s = {}
	self.level = (self.level or 0) + 1
	local indent = ("\t"):rep(self.level)

	if #self:GetData() <= 1 then
		indent = " "
	end

	if self:GetContract() and self:GetContract().Type == "table" then
		for i, keyval in ipairs(self:GetContract():GetData()) do
			local key, val = tostring(self:GetData()[i] and self:GetData()[i].key or "undefined"), tostring(self:GetData()[i] and self:GetData()[i].val or "undefined")
			local tkey, tval = tostring(keyval.key), tostring(keyval.val)

			if key == tkey then
				s[i] = indent .. key
			else
				s[i] = indent .. tkey .. " ⊃ " .. key
			end

			if val == tval then
				s[i] = s[i] .. " = " .. val
			else
				s[i] = s[i] .. " = " .. tval .. " ⊃ " .. val
			end
		end
	else
		for i, keyval in ipairs(self:GetData()) do
			local key, val = tostring(keyval.key), tostring(keyval.val)
			s[i] = indent .. key .. " = " .. val
		end
	end

	self.level = self.level - 1
	self.suppress = false
	if #self:GetData() <= 1 then return "{" .. table.concat(s) .. " }" end
	return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(self.level) .. "}"
end

function META:GetLength()
	return #self:GetData()
end

function META:FollowsContract(contract)
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
			if not ok then return ok, err end
		end
	end

	return true
end

function META.IsSubsetOf(A, B)
	if A.suppress then return true end
	if B.Type == "any" then return true end
	local ok, err = A:IsSameUniqueType(B)
	if not ok then return ok, err end
	if A == B then return true end

	if B.Type == "table" then
		if B:GetMetaTable() and B:GetMetaTable() == A then return true end
		local can_be_empty = true
		A.suppress = true

		for _, keyval in ipairs(B:GetData()) do
			if not keyval.val:CanBeNil() then
				can_be_empty = false

				break
			end
		end

		A.suppress = false

		if not A:GetData()[1] and (not A:GetContract() or not A:GetContract():GetData()[1]) then
			if can_be_empty then
				return true
			else
				return type_errors.subset(A, B)
			end
		end

		for _, akeyval in ipairs(A:GetData()) do
			local bkeyval, reason = B:FindKeyValReverse(akeyval.key)

			if not akeyval.val:CanBeNil() then
				if not bkeyval then return bkeyval, reason end
				A.suppress = true
				local ok, err = akeyval.val:IsSubsetOf(bkeyval.val)
				A.suppress = false
				if not ok then return type_errors.subset(akeyval.val, bkeyval.val, err) end
			end
		end

		return true
	elseif B.Type == "union" then
		A.suppress = true
		local u = Union({A}):IsSubsetOf(B)
		A.suppress = false
		return u
	end

	return type_errors.subset(A, B)
end

function META:ContainsAllKeysIn(contract)
	for _, keyval in ipairs(contract:GetData()) do
		if keyval.key:IsLiteral() then
			local ok, err = self:FindKeyVal(keyval.key)

			if not ok then
				if
					(keyval.val.Type == "symbol" and keyval.val:GetData() == nil) or
					(keyval.val.Type == "union" and keyval.val:CanBeNil())
				then
					return true
				end

				return type_errors.other(tostring(keyval.key) .. " is missing from " .. tostring(contract))
			end
		end
	end

	return true
end

function META:IsDynamic()
	return true
end

function META:Delete(key)
	for i, keyval in ipairs(self:GetData()) do
		if key:IsSubsetOf(keyval.key) and keyval.key:IsLiteral() then
			keyval.val:SetParent()
			keyval.key:SetParent()
			table.remove(self:GetData(), i)
		end
	end

	return true
end

function META:GetKeyUnion() -- never called
	local union = Union()

	for _, keyval in ipairs(self:GetData()) do
		union:AddType(keyval.key:Copy())
	end

	return union
end

function META:Contains(key)
	key = types.Literal(key)
	return self:FindKeyValReverse(key)
end

function META:FindKeyVal(key)
	local reasons = {}

	for _, keyval in ipairs(self:GetData()) do
		local ok, reason = keyval.key:IsSubsetOf(key)
		if ok then return keyval end
		table.insert(reasons, reason)
	end

	if not reasons[1] then
		local ok, reason = type_errors.missing(self, key, "table is empty")
		reasons[1] = reason
	end

	return type_errors.missing(self, key, reasons)
end

function META:FindKeyValReverse(key)
	local reasons = {}

	for _, keyval in ipairs(self:GetData()) do
		local ok, reason = key:Equal(keyval.key)
		if ok then return keyval end
	end

	for _, keyval in ipairs(self:GetData()) do
		local ok, reason = key:IsSubsetOf(keyval.key)
		if ok then return keyval end
		table.insert(reasons, reason)
	end

	if not reasons[1] then
		local ok, reason = type_errors.missing(self, key, "table is empty")
		reasons[1] = reason
	end

	return type_errors.missing(self, key, reasons)
end

function META:FindKeyValReverseEqual(key)
	local reasons = {}

	for _, keyval in ipairs(self:GetData()) do
		local ok, reason = key:Equal(keyval.key)
		if ok then return keyval end
		table.insert(reasons, reason)
	end

	if not reasons[1] then
		local ok, reason = type_errors.missing(self, key, "table is empty")
		reasons[1] = reason
	end

	return type_errors.missing(self, key, reasons)
end

function META:Insert(val)
	self.size = self.size or 1
	self:Set(self.size, val)
	self.size = self.size + 1
end

function META:GetEnvironmentValues()
	local values = {}

	for i, keyval in ipairs(self:GetData()) do
		values[i] = keyval.val
	end

	return values
end

function META:Set(key, val, no_delete)
	key = types.Literal(key)
	val = types.Literal(val)

	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
		self["Set" .. key:GetData():sub(2)](self, val)
		return true
	end

	if key.Type == "symbol" and key:GetData() == nil then return type_errors.other("key is nil") end

    -- delete entry
    if not no_delete and not self:GetContract() then
		if (val == nil or (val.Type == "symbol" and val:GetData() == nil)) then return self:Delete(key) end
	end

	if self:GetContract() and self:GetContract().Type == "table" then -- TODO
        local keyval, reason = self:GetContract():FindKeyValReverse(key)
		if not keyval then return keyval, reason end
		local keyval, reason = val:IsSubsetOf(keyval.val)
		if not keyval then return keyval, reason end
	end

    -- if the key exists, check if we can replace it and maybe the value
    local keyval, reason = self:FindKeyValReverse(key)

	if not keyval then
		val:SetParent(self)
		key:SetParent(self)
		table.insert(self.data, {key = key, val = val})
	else
		if keyval.key:IsLiteral() and keyval.key:Equal(key) then
			keyval.val = val
		else
			keyval.val = Union({keyval.val, val})
		end
	end

	return true
end

function META:SetExplicit(key, val)
	key = types.Literal(key)
	val = types.Literal(val)

	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
		self["Set" .. key:GetData():sub(2)](self, val)
		return true
	end

	if key.Type == "symbol" and key:GetData() == nil then return type_errors.other("key is nil") end

    -- if the key exists, check if we can replace it and maybe the value
    local keyval, reason = self:FindKeyValReverseEqual(key)

	if not keyval then
		val:SetParent(self)
		key:SetParent(self)
		table.insert(self.data, {key = key, val = val})
	else
		if keyval.key:IsLiteral() and keyval.key:Equal(key) then
			keyval.val = val
		else
			keyval.val = Union({keyval.val, val})
		end
	end

	return true
end

function META:Get(key)
	key = types.Literal(key)
	if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then return self["Get" .. key:GetData():sub(2)](self) end

	if key.Type == "union" then
		local union = Union({})
		local errors = {}

		for _, k in ipairs(key:GetData()) do
			local obj, reason = self:Get(k)

			if obj then
				union:AddType(obj)
			else
				table.insert(errors, reason)
			end
		end

		if union:GetLength() == 0 then return type_errors.other(errors) end
		return union
	end

	if (key.Type == "string" or key.Type == "number") and not key:IsLiteral() then
		local union = Union({types.Nil()})

		for _, keyval in ipairs(self:GetData()) do
			if keyval.key.Type == key.Type then
				union:AddType(keyval.val)
			end
		end

		return union
	end

	local keyval, reason = self:FindKeyValReverse(key)
	if keyval then return keyval.val end

	if not keyval and self:GetContract() then
		local keyval, reason = self:GetContract():FindKeyValReverse(key)
		if keyval then return keyval.val end
		return type_errors.other(reason)
	end

	return type_errors.other(reason)
end

function META:IsNumericallyIndexed()
	for _, keyval in ipairs(self:GetData()) do
		if keyval.key.Type ~= "number" then return false end
	end

	return true
end

function META:CopyLiteralness(from)
	if not from:GetData() then return false end

	for _, keyval_from in ipairs(from:GetData()) do
		local keyval, reason = self:FindKeyVal(keyval_from.key)
		if not keyval then return type_errors.other(reason) end

		if keyval_from.key.Type == "table" then
			keyval.key:CopyLiteralness(keyval_from.key) -- TODO: never called
		else
			keyval.key:SetLiteral(keyval_from.key:IsLiteral())
		end

		if keyval_from.val.Type == "table" then
			keyval.val:CopyLiteralness(keyval_from.val)
		else
			keyval.val:SetLiteral(keyval_from.val:IsLiteral())
		end
	end

	return true
end

function META:Copy(map)
	map = map or {}
	local copy = META.New()
	map[self] = map[self] or copy

	for i, keyval in ipairs(self:GetData()) do
		local k, v = keyval.key, keyval.val
		k = map[keyval.key] or k:Copy(map)
		map[keyval.key] = map[keyval.key] or k
		v = map[keyval.val] or v:Copy(map)
		map[keyval.val] = map[keyval.val] or v
		copy:GetData()[i] = {key = k, val = v}
	end

	copy:CopyInternalsFrom(self)
	copy.potential_self = self.potential_self
	copy.mutable = self.mutable
	copy:SetLiteral(self:IsLiteral())
	copy.mutations = self.mutations
	
	--[[
		
		copy.suppress = self.suppress
		copy.level = self.level
		copy.upvalue = self.upvalue
		copy.upvalue_keyref = self.upvalue_keyref
		copy.argument_index = self.argument_index
		copy.parent = self.parent
		copy.reference_id = self.reference_id
		]]

	if self.Self then
		copy:SetSelf(self.Self:Copy())
	end

	if self.MetaTable then
		copy:SetMetaTable(self.MetaTable)
	end

	return copy
end

function META:pairs()
	local i = 1
	return function()
		local keyval = self:GetData() and
			self:GetData()[i] or
			self:GetContract() and
			self:GetContract()[i]
		if not keyval then return nil end
		i = i + 1
		return keyval.key, keyval.val
	end
end

function META:HasLiteralKeys()
	if self.suppress then return true end

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
			if not ok then return type_errors.other("the key " .. tostring(v.key) .. " is not a literal because " .. tostring(reason)) end
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
			if not ok then return type_errors.other("the key " .. tostring(v.key) .. " is not a literal because " .. tostring(reason)) end
			self.suppress = true
			local ok, reason = v.val:IsLiteral()
			self.suppress = false
			if not ok then return type_errors.other("the value " .. tostring(v.val) .. " is not a literal because " .. tostring(reason)) end
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

local function unpack_keyval(keyval)
	local key, val = keyval.key, keyval.val
	return key, val
end

function META.Extend(A, B, dont_copy_self)
	if B.Type ~= "table" then return false, "cannot extend non table" end
	local map = {}

	if not dont_copy_self then
		A = A:Copy(map)
	end

	map[B] = A
	B = B:Copy(map)

	if A:GetContract() then
		A = A:GetContract()
	end

	for _, keyval in ipairs(B:GetData()) do
		local ok, reason = A:SetExplicit(unpack_keyval(keyval))
		if not ok then return ok, reason end
	end

	return A
end

function META.Union(A, B)
	local copy = META.New({})

	for _, keyval in ipairs(A:GetData()) do
		copy:Set(unpack_keyval(keyval))
	end

	for _, keyval in ipairs(B:GetData()) do
		copy:Set(unpack_keyval(keyval))
	end

	return copy
end

function META:Call(analyzer, arguments, ...)
	local __call = self:GetMetaTable() and self:GetMetaTable():Get("__call")

	if __call then
		local new_arguments = {self}

		for _, v in ipairs(arguments:GetData()) do
			table.insert(new_arguments, v)
		end

		return analyzer:Call(__call, Tuple(new_arguments), ...)
	end

	return type_errors.other("table has no __call metamethod")
end

function META:PrefixOperator(op)
	if op == "#" then return Number(self:GetLength()):SetLiteral(self:IsLiteral()) end
end

function META.New(data)
	return setmetatable({data = data or {}}, META)
end

return {Table = META.New}
