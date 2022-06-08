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

function META:SetNode(node)
	self.Node = node
	return self
end

function META:GetNode()
	return self.Node
end

function META:GetHash()
	return self.hash
end

local id = 0

function META.New(obj)
	local self = setmetatable({}, META)
	self.hash = tostring(id)
	id = id + 1
	self:SetValue(obj)
	return self
end

return META