--ANALYZE
local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("base")
--[[#type META.Type = string]]
--[[#type META.@Self = {
	suppress = any,
	Self = any,
	potential_self = any,
	parent_table = any,
	dont_widen = any,
	truthy_union = any,
	falsy_union = any,
	right_source = any,
	left_source = any,
	Name = string | false,
	parent = any | false,
	Parent = any,
	is_enum = any,
	UniqueID = any,
}]]
--[[#local type TBaseType = META.@Self]]

--[[#type META.TBaseType = TBaseType]] --copy<|META|>.@Self

--[[#type META.Type = string]]
META:GetSet("AnalyzerEnvironment", false--[[# as false | "runtime" | "typesystem"]])

function META.Equal(a--[[#: TBaseType]], b--[[#: TBaseType]]) --error("nyi " .. a.Type .. " == " .. b.Type)
end

function META:CanBeNil()
	return false
end

META:GetSet("Data", nil--[[# as nil | any]])

function META:GetLuaType()
	local contract = self:GetContract()

	if contract then
		local to = contract.TypeOverride

		if to and to.Type == "string" and to.Data then return to.Data end
	end

	local to = self.TypeOverride
	return to and to.Type == "string" and to.Data or self.Type
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
	META:GetSet("Upvalue", false--[[# as false | any]])
	META:GetSet("Node", false--[[# as false | any]])

	function META:SetNode(node--[[#: false | any]], is_local--[[#: nil | boolean]])
		self.Node = node
		return self
	end
end

do -- comes from tbl.@Name = "my name"
	META:GetSet("Name", false--[[# as false | TBaseType]])

	function META:SetName(name--[[#: TBaseType | false]])
		if name then assert(name:IsLiteral()) end

		self.Name = name
	end
end

do -- comes from tbl.@TypeOverride = "my name"
	META:GetSet("TypeOverride", false--[[# as false | TBaseType]])

	function META:SetTypeOverride(name--[[#: false | TBaseType]])
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
	function META:IsLiteral()
		return false
	end

	function META:Widen()
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
	META:GetSet("Parent", false--[[# as TBaseType | false]])

	function META:SetParent(parent--[[#: TBaseType | false | nil]])
		if parent then
			if parent ~= self then self.Parent = parent end
		else
			self.Parent = false
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

	META:GetSet("Contract", false--[[# as TBaseType | false]])
end

do
	META:GetSet("MetaTable", false--[[# as TBaseType | false]])

	function META:GetMetaTable()
		local contract = self:GetContract()

		if contract and contract.MetaTable then return contract.MetaTable end

		return self.MetaTable
	end
end

function META:GetFirstValue()
	-- for tuples, this would return the first value in the tuple
	return self
end

function META.LogicalComparison(l--[[#: TBaseType]], r--[[#: TBaseType]], op--[[#: string]])
	return false, type_errors.binary(op, l, r)
end

function META.New()
	return setmetatable(
		{
			suppress = false,
			Self = false,
			potential_self = false,
			parent_table = false,
			dont_widen = false,
			truthy_union = false,
			right_source = false,
			left_source = false,
			TypeOverride = false,
			Falsy = false,
			Truthy = false,
			falsy_union = false,
			right_source = false,
			Data = nil,
            Name = false,
            parent = false,
            AnalyzerEnvironment = false,
            Upvalue = false,
            Node = false,
            ReferenceType = false,
            Parent = false,
            Contract = false,
            MetaTable = false,
			is_enum = false,
			UniqueID = false,
		},
		META
	)
end
return META
