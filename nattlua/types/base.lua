--ANALYZE
local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local error_messages = require("nattlua.error_messages")
local class = require("nattlua.other.class")
return function()
	local META = class.CreateTemplate("base")
	--[[#type META.Type = string]]
	--[[#type META.@Self = {
		Type = string,
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

	function META:CanBeNil()
		return false
	end

	function META:GetLuaType()
		return self.Type
	end

	META:GetSet("Data", false--[[# as any]])

	do
		META:GetSet("TruthyFalsy", false--[[# as "truthy" | "falsy" | "unknown"]])

		function META:IsTruthy()
			return self.TruthyFalsy == "truthy" or self.TruthyFalsy == "unknown"
		end
		
		function META:IsFalsy()
			return self.TruthyFalsy == "falsy" or self.TruthyFalsy == "unknown"
		end

		function META:IsUncertain()
			return self:IsTruthy() and self:IsFalsy()
		end

		function META:IsCertainlyFalse()
			return self:IsFalsy() and not self:IsTruthy()
		end

		function META:IsCertainlyTrue()
			return self:IsTruthy() and not self:IsFalsy()
		end
		
	end

	do
		function META:Copy()
			return self
		end

		function META:CopyInternalsFrom(obj--[[#: TBaseType]])
			self:SetContract(obj:GetContract())
		end
	end

	do -- token, expression and statement association
		META:GetSet("Upvalue", false--[[# as false | any]])
	end

	function META:GetHashForMutationTracking()
		return nil
	end

	do
		function META:IsLiteral()
			return false
		end

		function META:Widen()
			return self
		end

		function META:CopyLiteralness()
			return self
		end
	end

	do -- operators
		function META:Set(key--[[#: TBaseType | nil]], val--[[#: TBaseType | nil]])
			return false, error_messages.undefined_set(self, key, val, self.Type)
		end

		function META:Get(key--[[#: boolean]])
			return false, error_messages.undefined_get(self, key, self.Type)
		end
	end

	do -- contract
		META:GetSet("Contract", false--[[# as TBaseType | false]])
	end

	function META:GetFirstValue()
		-- for tuples, this would return the first value in the tuple
		return self
	end

	function META.LogicalComparison(l--[[#: TBaseType]], r--[[#: TBaseType]], op--[[#: string]])
		return false, error_messages.binary(op, l, r)
	end

	function META:IsNumeric()
		return false
	end

	return META
end
