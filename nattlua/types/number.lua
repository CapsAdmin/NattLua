local type_errors = require("nattlua.types.error_messages")
local META = {}
META.Type = "number"
require("nattlua.types.base")(META)
--[[#type META.max = META]]
--[[#type META.data = number]]

function META.Equal(a, b)
	if a.Type ~= b.Type then return false end

	if a:IsLiteral() and b:IsLiteral() then
        -- nan
        if a:GetData() ~= a:GetData() and b:GetData() ~= b:GetData() then return true end
		return a:GetData() == b:GetData()
	end

	if a.max and b.max and a.max:Equal(b.max) then return true end
	if a.max or b.max then return false end
	if not a:IsLiteral() and not b:IsLiteral() then return true end
	return false
end

function META:GetLuaType()
	return self.Type
end

function META:Copy()
	local copy = self:New(self:GetData()):SetLiteral(self:IsLiteral())

	if self.max then
		copy.max = self.max:Copy()
	end

	copy:CopyInternalsFrom(self)
	return copy
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

	if B.Type == "number" then
		if A:IsLiteral() == true and B:IsLiteral() == true then
            -- compare against literals

            -- nan
            if A.Type == "number" and B.Type == "number" then
				if A:GetData() ~= A:GetData() and B:GetData() ~= B:GetData() then return true end
			end

			if A:GetData() == B:GetData() then return true end

			if B.max then
				if A:GetData() >= B:GetData() and A:GetData() <= B.max:GetData() then return true end
			end

			return type_errors.subset(A, B)
		elseif A:GetData() == nil and B:GetData() == nil then
            -- number contains number
            return true
		elseif A:IsLiteral() and not B:IsLiteral() then
            -- 42 subset of number?
            return true
		elseif not A:IsLiteral() and B:IsLiteral() then
            -- number subset of 42 ?
            return type_errors.subset(A, B)
		end

        -- number == number
        return true
	else
		return type_errors.type_mismatch(A, B)
	end

	error("this shouldn't be reached")
	return false
end

function META:__tostring()
	local n = self:GetData()

	if n ~= n then
		n = "nan"
	end

	local s = tostring(n)

	if self.max then
		s = s .. ".." .. tostring(self.max)
	end

	if self:IsLiteral() then return s end
	if self:GetData() then return "number(" .. s .. ")" end
	return "number"
end

function META:SetMax(val)
	local err

	if val.Type == "union" then
		val, err = val:GetLargestNumber()
		if not val then return val, err end
	end

	if val.Type ~= "number" then return type_errors.other("max must be a number, got " .. tostring(val)) end

	if val:IsLiteral() then
		self.max = val
	else
		self:SetLiteral(false)
		self:SetData(nil)
	end

	return self
end

function META:GetMax()
	return self.max
end

function META:IsFalsy()
	return false
end

function META:IsTruthy()
	return true
end

return META
