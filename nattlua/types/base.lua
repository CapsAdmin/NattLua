--ANALYZE
local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local error_messages = require("nattlua.error_messages")
local shared = require("nattlua.types.shared")
local class = require("nattlua.other.class")
return function()
	local META = class.CreateTemplate("base")
	--[[#type META.Type = string]]
	--[[#type META.@SelfArgument = {
		Type = string,
	}]]
	--[[#local type TBaseType = META.@SelfArgument]]
	--[[#type META.TBaseType = TBaseType]]
	--[[#type META.Type = string]]

	function META.Equal(a--[[#: TBaseType]], b--[[#: TBaseType]], visited--[[#: any]])--[[#: boolean, string | nil]]
		return shared.Equal(a, b, visited)
	end

	function META:IsSubsetOf(other--[[#: TBaseType]], visited--[[#: any]])--[[#: boolean, string | nil]]
		return shared.IsSubsetOf(self, other, visited)
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
			return shared.Set(self, key, val)
		end

		function META:Get(key--[[#: boolean]])
			return shared.Get(self, key)
		end
	end

	do -- contract
		META:GetSet("Contract", false--[[# as TBaseType | false]])
	end

	function META:GetFirstValue()
		-- for tuples, this would return the first value in the tuple
		return self
	end

	function META:IsNumeric()
		return false
	end

	return META
end