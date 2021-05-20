local error = _G.error
local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local META = {}
META.__index = META

function META.GetSet(tbl--[[#: literal any]], name--[[#: literal string]], default--[[#: literal any]])
	tbl[name] = default--[[# as NonLiteral<|default|>]]
--[[#	type tbl.@Self[name] = tbl[name] ]]
	tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: typeof tbl[name] ]])
		self[name] = val
		return self
	end
	tbl["Get" .. name] = function(self--[[#: tbl.@Self]])--[[#: typeof tbl[name] ]]
		return self[name]
	end
end

function META.IsSet(tbl--[[#: literal any]], name--[[#: literal string]], default--[[#: literal any]])
	tbl[name] = default--[[# as NonLiteral<|default|>]]
--[[#	type tbl.@Self[name] = tbl[name] ]]
	tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: typeof tbl[name] ]])
		self[name] = val
		return self
	end
	tbl["Is" .. name] = function(self--[[#: tbl.@Self]])--[[#: typeof tbl[name] ]]
		return self[name]
	end
end

--[[#type META.Type = string]]
--[[#type META.@Self = {}]]
--[[#type BaseType = META.@Self]]
--[[#type BaseType.Data = any | nil]]
--[[#type BaseType.Name = string | nil]]
--[[#type BaseType.upvalue = any | nil]]
--[[#type BaseType.upvalue_keyref = any | nil]]
--[[#type BaseType.parent = BaseType | nil]]
META:GetSet("Environment", nil--[[# as nil | "runtime" | "typesystem"]])

function META.Equal(a--[[#: BaseType]], b--[[#: BaseType]])
	--error("nyi " .. a.Type .. " == " .. b.Type)
end

function META:CanBeNil()
	return false
end

META:GetSet("Data", nil)

do
--[[#	type BaseType.falsy = boolean | nil]]
--[[#	type BaseType.truthy = boolean | nil]]

	function META:IsUncertain()
		return self:IsTruthy() and self:IsFalsy()
	end

	META:IsSet("Falsy", false)
	META:IsSet("Truthy", false)
end

do
	function META:Copy()
		return self
	end

	function META:CopyInternalsFrom(obj)
		self:SetNode(obj:GetNode())
		self:SetTokenLabelSource(obj:GetTokenLabelSource())
		self:SetTypeSource(obj:GetTypeSource())
		self:SetTypeSourceLeft(obj:GetTypeSourceLeft())
		self:SetTypeSourceRight(obj:GetTypeSourceRight())
		self:SetLiteral(obj:IsLiteral())
		self:SetContract(obj:GetContract())
		self:SetName(obj:GetName())
		self:SetMetaTable(obj:GetMetaTable())
		self:SetEnvironment(obj:GetEnvironment())

		-- what about these?
		--self.upvalue_keyref = obj.upvalue_keyref
		--self.upvalue = obj.upvalue
	end
end

do
--[[#
--[[#
--[[# -- token, expression and statement association

	--[[#
		type BaseType.unique_id = number | nil]]
--[[#	type BaseType.disabled_unique_id = number | nil]]

	function META:SetUpvalue(obj--[[#: any]], key--[[#: string | nil]])
		self.upvalue = obj

		if key then
			self.upvalue_keyref = key
		end
	end

	META:GetSet("TokenLabelSource", nil)
	META:GetSet("TypeSource", nil)
	META:GetSet("TypeSourceLeft", nil)
	META:GetSet("TypeSourceRight", nil)
	META:GetSet("Node")
end

do -- comes from tbl.@Name = "my name"
	function META:SetName(name--[[#: BaseType]])
		if name then
			assert(name:IsLiteral())
		end

		self.Name = name
	end

	function META:GetName()
		return self.Name
	end
end

do
	local ref = 0

	function META:MakeUnique(b--[[#: boolean]])
		if b then
			self.unique_id = ref
			ref = ref + 1
		else
			self.unique_id = nil
		end

		return self
	end

	function META:IsUnique()
		return self.unique_id ~= nil
	end

	function META:GetUniqueID()
		return self.unique_id
	end

	function META:DisableUniqueness()
		self.disabled_unique_id = self.unique_id
		self.unique_id = nil
	end

	function META:EnableUniqueness()
		self.unique_id = self.disabled_unique_id
	end

	function META.IsSameUniqueType(a--[[#: BaseType]], b--[[#: BaseType]])
		if a.unique_id and not b.unique_id then return type_errors.other(tostring(a) .. "is a unique type") end
		if b.unique_id and not a.unique_id then return type_errors.other(tostring(b) .. "is a unique type") end
		if a.unique_id ~= b.unique_id then return type_errors.other(tostring(a) .. "is not the same unique type as " .. tostring(a)) end
		return true
	end
end

do
	META:IsSet("Literal", false)

	function META:CopyLiteralness(obj--[[#: BaseType]])
		self:SetLiteral(obj:IsLiteral())
	end
end

do -- operators
	function META:Call(...)
		return type_errors.other("type " .. self.Type .. ": " .. tostring(self) .. " cannot be called")
	end

	function META:Set(key--[[#: BaseType | nil]], val--[[#: BaseType | nil]])
		return type_errors.other(
			"undefined set: " .. tostring(self) .. "[" .. tostring(key) .. "] = " .. tostring(val) .. " on type " .. self.Type
		)
	end

	function META:Get(key--[[#: boolean]])
		return type_errors.other(
			"undefined get: " .. tostring(self) .. "[" .. tostring(key) .. "]" .. " on type " .. self.Type
		)
	end

	function META:PrefixOperator(op--[[#: string]])
		return type_errors.other("no operator " .. op .. " on " .. tostring(self))
	end
end

do
	function META:SetParent(parent--[[#: BaseType | nil]])
		if parent then
			if parent ~= self then
				self.parent = parent
			end
		else
			self.parent = nil
		end
	end

	function META:GetRoot()
		local parent = self
		local done = {}

		while true do
			if not parent.parent or done[parent] then break end
			done[parent] = true
			parent = parent.parent
		end

		return parent
	end
end

do
	META:GetSet("MetaTable", nil--[[# as BaseType | nil]])

	function META:GetMetaTable()
		if self.Contract and self.Contract.MetaTable then return self.Contract.MetaTable end
		return self.MetaTable
	end
end

do -- contract
	function META:Seal()
		self:SetContract(self:GetContract() or self:Copy())
	end

	META:GetSet("Contract", nil--[[# as BaseType | nil]])
end

function META.New()
	return setmetatable({}, META)
end

return META
