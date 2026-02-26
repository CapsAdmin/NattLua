local setmetatable = _G.setmetatable
local getmetatable = _G.getmetatable
local shared = require("nattlua.types.shared")
local tostring = _G.tostring
local META = require("nattlua.types.base")()
META:GetSet("Reference", false)

function META:Unwrap(visited--[[#: any]])
	local ref = self:GetReference()

	if not (ref and ref ~= self) then
		local upv = self:GetUpvalue()

		if upv then ref = upv:GetValue() end
	end

	if ref and ref ~= self and ref.Type == "deferred" then
		return ref:Unwrap(visited)
	end

	return self
end

function META:IsResolved()
	local ref = self:GetReference()
	local upv = self:GetUpvalue()
	return (ref and ref ~= self) or (upv and upv:GetValue() and upv:GetValue() ~= self)
end

function META:IsTruthy()
	local unwrapped = self:Unwrap()

	if unwrapped == self then return true end

	return unwrapped:IsTruthy()
end

function META:IsFalsy()
	local unwrapped = self:Unwrap()

	if unwrapped == self then return false end

	return unwrapped:IsFalsy(visited)
end

function META:IsCertainlyTrue()
	local unwrapped = self:Unwrap()

	if unwrapped == self then return true end

	return unwrapped:IsCertainlyTrue()
end

function META:IsCertainlyFalse()
	local unwrapped = self:Unwrap()

	if unwrapped == self then return false end

	return unwrapped:IsCertainlyFalse()
end

function META:GetHash(visited)
	local unwrapped = self:Unwrap()

	if unwrapped == self then
		local upv = self:GetUpvalue()
		return "reference:" .. tostring(upv and upv:GetKey() or self)
	end

	return unwrapped:GetHash(visited)
end

function META:__tostring(visited)
	local unwrapped = self:Unwrap()

	if unwrapped == self then
		local upv = self:GetUpvalue()

		if upv then return "deferred upvalue " .. tostring(upv:GetKey()) end

		return "deferred reference*"
	end

	return tostring(unwrapped)
end

function META:GetLuaType()
	local unwrapped = self:Unwrap()

	if unwrapped == self then return "deferred" end

	return unwrapped:GetLuaType()
end

function META:IsNil()
	local unwrapped = self:Unwrap()

	if unwrapped == self then return false end

	return unwrapped:IsNil()
end

function META:CanBeNil()
	local unwrapped = self:Unwrap()

	if unwrapped == self then return true end -- assume nil if not resolved?
	return unwrapped:CanBeNil()
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables)
	map = map or {}

	if map[self] then return map[self] end

	local copy = self.New()
	map[self] = copy
	copy:SetUpvalue(self:GetUpvalue())
	copy:SetReference(self:GetReference())
	copy:CopyInternalsFrom(self)
	return copy
end

function META:Set(key, val)
	local unwrapped = self:Unwrap()

	if unwrapped == self then
		return false, "cannot set on unresolved deferred reference"
	end

	return unwrapped:Set(key, val)
end

function META:Get(key)
	local unwrapped = self:Unwrap()

	if unwrapped == self then
		return false, "cannot get from unresolved deferred reference"
	end

	return unwrapped:Get(key)
end

function META:__index(key)
	if key == "Type" then
		local unwrapped = self:Unwrap()

		if unwrapped ~= self then return unwrapped.Type end

		return "deferred"
	end

	if META[key] then return META[key] end

	local unwrapped = self:Unwrap()

	if unwrapped ~= self then return unwrapped[key] end
end

function META.New(name)
	return META.NewObject(
		{
			Type = "deferred",
			Reference = false,
			Upvalue = false,
			Contract = false,
		}
	)
end

return {
	Deferred = META.New,
}