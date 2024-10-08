--ANALYZE
local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("base")
--[[#type META.Type = string]]
--[[#type META.@Self = {
	Type = string,
	Parent = any,
}]]
--[[#local type TBaseType = META.@Self]]
--[[#type META.TBaseType = TBaseType]]
--[[#--copy<|META|>.@Self
type META.Type = string]]

function META.Equal(a--[[#: TBaseType]], b--[[#: TBaseType]]) --error("nyi " .. a.Type .. " == " .. b.Type)
end

function META:IsNil()
	return false
end

function META:GetLuaType()
	return self.Type
end


META:GetSet("Data", nil--[[# as nil | any]])

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
		self:SetReferenceType(obj:IsReferenceType())
	end
end

do -- token, expression and statement association
	META:GetSet("Upvalue", false--[[# as false | any]])
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

function META:GetFirstValue()
	-- for tuples, this would return the first value in the tuple
	return self
end

function META.LogicalComparison(l--[[#: TBaseType]], r--[[#: TBaseType]], op--[[#: string]])
	return false, type_errors.binary(op, l, r)
end

return META
