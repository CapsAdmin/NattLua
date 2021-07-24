local tostring = _G.tostring
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local table = require("table")
local Tuple = require("nattlua.types.tuple").Tuple
local Union = require("nattlua.types.union").Union
local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")
META.Type = "function"

function META:__call(...)
	if self:GetData().lua_function then return self:GetData().lua_function(...) end
end

function META.Equal(a, b)
	return
		a.Type == b.Type and
		a:GetArguments():Equal(b:GetArguments()) and
		a:GetReturnTypes():Equal(b:GetReturnTypes())
end

function META:__tostring()
	return "function" .. tostring(self:GetArguments()) .. ": " .. tostring(self:GetReturnTypes())
end

function META:GetLuaType()
	return "function"
end

function META:GetArguments()
	return self:GetData().arg or Tuple({})
end

function META:GetReturnTypes()
	return self:GetData().ret or Tuple({})
end

function META:HasExplicitReturnTypes()
	return self.explicit_return_set
end

function META:SetReturnTypes(tup)
	self:GetData().ret = tup
	self.explicit_return_set = tup
	self.called = nil
end

function META:SetArguments(tup)
	self:GetData().arg = tup
	self.called = nil
end

function META:Copy(map)
	map = map or {}
	local copy = self.New({arg = Tuple({}), ret = Tuple({})})
	map[self] = map[self] or copy
	copy:GetData().ret = self:GetReturnTypes():Copy(map)
	copy:GetData().arg = self:GetArguments():Copy(map)
	copy:GetData().lua_function = self:GetData().lua_function
	copy:GetData().scope = self:GetData().scope
	copy:SetLiteral(self:IsLiteral())
	copy:CopyInternalsFrom(self)
	copy.function_body_node = self.function_body_node
	return copy
end

function META.IsSubsetOf(A, B)
	if B.Type == "any" then return true end
	if B.Type ~= "function" then return type_errors.type_mismatch(A, B) end
	local ok, reason = A:GetArguments():IsSubsetOf(B:GetArguments())
	if not ok then return type_errors.subset(A:GetArguments(), B:GetArguments(), reason) end
	local ok, reason = A:GetReturnTypes():IsSubsetOf(B:GetReturnTypes())

	if
		not ok and
		((not B.called and not B.explicit_return) or (not A.called and not A.explicit_return))
	then
		return true
	end

	if not ok then return type_errors.subset(A:GetReturnTypes(), B:GetReturnTypes(), reason) end
	return true
end

function META:IsFalsy()
	return false
end

function META:IsTruthy()
	return true
end

function META:AddScope(arguments, return_result, scope)
	self.scopes = self.scopes or {}
	table.insert(
		self.scopes,
		{
			arguments = arguments,
			return_result = return_result,
			scope = scope,
		}
	)
end

function META:GetSideEffects()
	local out = {}

	for _, call_info in ipairs(self.scopes) do
		for _, val in ipairs(call_info.scope:GetDependencies()) do
			if val.scope ~= call_info.scope then
				table.insert(out, val)
			end
		end
	end

	return out
end

function META:GetCallCount()
	return #self.scopes
end

function META:IsPure()
	return #self:GetSideEffects() == 0
end

function META.New(data)
	return setmetatable({Data = data or {}}, META)
end

return
	{
		Function = META.New,
		LuaRuntimeFunction = function() 
		end,
		LuaTypeFunction = function(lua_function, arg, ret)
			local self = META.New()
			self:SetData(
				{
					arg = Tuple(arg),
					ret = Tuple(ret),
					lua_function = lua_function,
				}
			)
			return self
		end,
	}
