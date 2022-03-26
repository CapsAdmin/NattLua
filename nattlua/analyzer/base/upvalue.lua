local class = require("nattlua.other.class")
local META = class.CreateTemplate("upvalue")

function META:__tostring()
	return "[" .. tostring(self.key) .. ":" .. tostring(self.value) .. "]"
end

function META:GetValue()
	return self.value
end

function META:GetKey()
	return self.key
end

function META:SetValue(value)
	self.value = value
	value:SetUpvalue(self)
end

function META:SetImmutable(b)
	self.immutable = b
end

function META:IsImmutable()
	return self.immutable
end

function META.New(obj)
	local self = setmetatable({}, META)
	self:SetValue(obj)
	return self
end

return META
