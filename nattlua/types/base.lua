--ANALYZE
local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("base")
--[[#type META.Type = string]]
--[[#type META.@Self = {}]]
--[[#local type TBaseType = META.@Self]]
--[[#type TBaseType.@Name = "TBaseType"]]
--[[#type META.Type = string]]
--[[#type TBaseType.Name = string | nil]]
--[[#type TBaseType.parent = TBaseType | nil]]
--[[#type TBaseType.truthy_union = TBaseType | nil]]
--[[#type TBaseType.falsy_union = TBaseType | nil]]
META:GetSet("AnalyzerEnvironment", nil--[[# as nil | "runtime" | "typesystem"]])

function META.Equal(a--[[#: TBaseType]], b--[[#: TBaseType]]) --error("nyi " .. a.Type .. " == " .. b.Type)
end

function META:CanBeNil()
	return false
end

META:GetSet("Data", nil--[[# as nil | any]])

function META:GetLuaType()
	local contract = self:GetContract()

	if
		contract and
		contract.TypeOverride and
		contract.TypeOverride.Type == "string" and
		contract.TypeOverride.Data
	then
		return contract.TypeOverride.Data
	end

	return self.TypeOverride and
		self.TypeOverride.Type == "string" and
		self.TypeOverride.Data or
		self.Type
end

do
	function META:IsUncertain()
		return self:IsTruthy() and self:IsFalsy()
	end

	function META:IsCertainlyFalse()
		return self:IsFalsy() and not self:IsTruthy()
	end

	function META:IsCertainlyTrue()
		return self:IsTruthy() and not self:IsFalsy()
	end

	function META:GetTruthy()
		if self:IsTruthy() then return self end

		return nil
	end

	function META:GetFalsy()
		if self:IsFalsy() then return self end

		return nil
	end

	META:IsSet("Falsy", false--[[# as boolean]])
	META:IsSet("Truthy", false--[[# as boolean]])
end

do
	function META:Copy()
		return self
	end

	function META:CopyInternalsFrom(obj--[[#: mutable TBaseType]])
		self:SetLiteral(obj:IsLiteral())
		self:SetContract(obj:GetContract())
		self:SetName(obj:GetName())
		self:SetMetaTable(obj:GetMetaTable())
		self:SetAnalyzerEnvironment(obj:GetAnalyzerEnvironment())
		self:SetTypeOverride(obj:GetTypeOverride())
		self:SetReferenceType(obj:IsReferenceType())
		self.truthy_union = obj.truthy_union
		self.falsy_union = obj.falsy_union
	end
end

do -- token, expression and statement association
	META:GetSet("Upvalue", nil--[[# as nil | any]])
	META:GetSet("Node", nil--[[# as nil | any]])

	function META:SetNode(node--[[#: nil | any]], is_local--[[#: nil | boolean]])
		self.Node = node
		return self
	end
end

do -- comes from tbl.@Name = "my name"
	META:GetSet("Name", nil--[[# as nil | TBaseType]])

	function META:SetName(name--[[#: TBaseType | nil]])
		if name then assert(name:IsLiteral()) end

		self.Name = name
	end
end

do -- comes from tbl.@TypeOverride = "my name"
	META:GetSet("TypeOverride", nil--[[# as nil | TBaseType]])

	function META:SetTypeOverride(name--[[#: nil | TBaseType]])
		self.TypeOverride = name
	end
end

function META:GetHash()
	return nil
end

do
	META:IsSet("ReferenceType", false--[[# as boolean]])
end

do
	META:IsSet("Literal", false--[[# as boolean]])

	function META:CopyLiteralness(obj--[[#: TBaseType]])
		local self = self:Copy()
		if obj:IsReferenceType() then
			self:SetLiteral(true)
			self:SetReferenceType(true)
		else
			self:SetLiteral(obj:IsLiteral())
		end
		return self
	end
end

do -- operators
	function META:Set(key--[[#: TBaseType | nil]], val--[[#: TBaseType | nil]])
		return false, type_errors.undefined_set(self, key, val, self.Type)
	end

	function META:Get(key--[[#: boolean]])
		return false, type_errors.undefined_get(self, key, self.Type)
	end
end

do
	META:GetSet("Parent", nil--[[# as TBaseType | nil]])

	function META:SetParent(parent--[[#: TBaseType | nil]])
		if parent then
			if parent ~= self then self.Parent = parent end
		else
			self.Parent = nil
		end
	end

	function META:GetRoot()
		local parent = self
		local done = {}

		while true do
			if not parent.Parent or done[parent] then break end

			done[parent] = true
			parent = parent.Parent--[[# as any]]
		end

		return parent
	end
end

do -- contract
	function META:Seal()
		self:SetContract(self:GetContract() or self:Copy())
	end

	META:GetSet("Contract", nil--[[# as TBaseType | nil]])
end

do
	META:GetSet("MetaTable", nil--[[# as TBaseType | nil]])

	function META:GetMetaTable()
		local contract = self:GetContract()

		if contract and contract.MetaTable then return contract.MetaTable end

		return self.MetaTable
	end
end

function META:Widen()
	return self
end

function META:GetFirstValue()
	-- for tuples, this would return the first value in the tuple
	return self
end

function META.LogicalComparison(l--[[#: TBaseType]], r--[[#: TBaseType]], op--[[#: string]])
	return false, type_errors.binary(op, l, r)
end

function META.New()
	return setmetatable({}--[[# as META.@Self]], META)
end

--[[#type META.TBaseType = any]] --copy<|META|>.@Self
return META