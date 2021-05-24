local type = type
local tostring = tostring
local ipairs = ipairs
local table = require("table")
local type_errors = require("nattlua.types.error_messages")
local META = dofile("nattlua/types/base.lua")
META.Type = "symbol"

function META.Equal(a, b)
	return a.Type == b.Type and a:GetData() == b:GetData()
end

function META:GetLuaType()
	return type(self:GetData())
end

function META:__tostring()
	return tostring(self:GetData())
end

function META:Copy()
	local copy = self.New(self:GetData())
	copy:CopyInternalsFrom(self)
	return copy
end

function META:CanBeNil()
	return self:GetData() == nil
end

function META.IsSubsetOf(A, B)
	if B.Type == "tuple" and B:GetLength() == 1 then
		B = B:Get(1)
	end

	if B.Type == "union" then
		local errors = {}

		for _, b in ipairs(B:GetData()) do
			local ok, reason = A:IsSubsetOf(b)
			if ok then return true end
			table.insert(errors, reason)
		end

		return type_errors.subset(A, B, errors)
	end

	if A.Type == "any" then return true end
	if B.Type == "any" then return true end
	if A.Type ~= B.Type then return type_errors.type_mismatch(A, B) end
	if A:GetData() ~= B:GetData() then return type_errors.value_mismatch(A, B) end
	return true
end

function META:IsFalsy()
	return not self.Data
end

function META:IsTruthy()
	return not not self.Data
end

function META.New(data)
	local self = setmetatable({Data = data}, META)
	self:SetLiteral(true)
	return self
end

local Symbol = META.New
return
	{
		Symbol = Symbol,
		Nil = function()
			return Symbol(nil)
		end,
		True = function()
			return Symbol(true)
		end,
		False = function()
			return Symbol(false)
		end,
		Boolean = function()
			local Union = require("nattlua.types.union").Union
			return Union({Symbol(true), Symbol(false)})
		end,
	}
