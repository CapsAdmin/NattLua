local table_sort = table.sort
local table_concat = table.concat
local hash_type
local sort = function(a--[[#: string]], b--[[#: string]])
	return a < b
end

local function hash_tuple(self)
	if self.suppress_hash then return "current_tuple" end

	self.suppress_hash = true
	local strings--[[#: List<|string|>]] = {}

	for i, v in ipairs(self:GetData()) do
		strings[i] = hash_type(v)
	end

	if self.Remainder then table.insert(strings, hash_type(self.Remainder)) end

	local s = "("

	if #strings == 1 and strings[1] then
		s = s .. strings[1] .. ","
	else
		s = s .. table.concat(strings, ", ")
	end

	s = s .. ")"

	if self.Repeat then s = s .. "*" .. tostring(self.Repeat) end

	self.suppress_hash = false
	return s
end

local function hash_union(self)
	if self.suppress_hash then return "current_union" end

	local s = {}
	self.suppress_hash = true

	for i, v in ipairs(self.Data) do
		s[i] = hash_type(v)
	end

	if not s[1] then
		self.suppress_hash = false
		return "|"
	end

	self.suppress_hash = false

	if #s == 1 then return (s[1]--[[# as string]]) .. "|" end

	table_sort(s, sort)
	return table_concat(s, " | ")
end

local function hash_table(self)
	if self:GetContract() and self:GetContract().Name then
		return "TABLE-NAME-" .. self:GetContract().Name:GetData()
	end

	if self.Name then return "TABLE-NAME-" .. self.Name:GetData() end

	if self:IsUnique() then return tostring(self:GetUniqueID()) end

	if self.suppress_hash then return "current_table" end

	self.suppress_hash = true
	local s = {}
	local contract = self:GetContract()

	if contract and contract.Type == "table" and contract ~= self then
		for i, keyval in ipairs(contract:GetData()) do
			local key = self:GetData()[i] and hash_type(self:GetData()[i].key) or "nil"
			local val = self:GetData()[i] and hash_type(self:GetData()[i].val) or "nil" -- TOOD: ?? 
			local tkey, tval = hash_type(keyval.key), hash_type(keyval.val)

			if key == tkey then
				s[i] = "[" .. key .. "]"
			else
				s[i] = "[" .. key .. " as " .. tkey .. "]"
			end

			if val == tval then
				s[i] = s[i] .. " = " .. val
			else
				s[i] = s[i] .. " = " .. val .. " as " .. tval
			end
		end
	else
		for i, keyval in ipairs(self:GetData()) do
			local key = hash_type(keyval.key)
			local val = hash_type(keyval.val)
			s[i] = "[" .. key .. "]" .. " = " .. val
		end
	end

	self.suppress_hash = false
	table_sort(s, sort)

	if #self:GetData() <= 1 then return "{" .. table.concat(s, ",") .. " }" end

	return "{" .. table.concat(s, ",") .. "}"
end

local function hash_string(self)
	if self.Data then return "STRING-" .. self.Data end

	return "string"
end

local function hash_number(self)
	if self:IsNan() then return "nan" end

	if self.Data then
		if self.Max then
			if self.Max ~= false and self.Data then
				return tostring(self.Data) .. "-" .. tostring(self.Max)
			end
		end

		return tostring(self.Data)
	end

	return "number"
end

local function hash_function(self)
	return "function=" .. hash_type(self:GetInputSignature()) .. ">" .. hash_type(self:GetOutputSignature())
end

local function hash_any(self)
	return "any"
end

local function hash_symbol(self)
	if self:IsTrue() then
		return "true"
	elseif self:IsFalse() then
		return "false"
	elseif self:IsNil() then
		return "nil"
	end

	return tostring(self:GetData())
end

function hash_type(obj)
	if type(obj) ~= "table" or obj.Type == nil then
		print(obj)
		error(debug.traceback("wtf"))
	end

	if obj.Type == "union" then
		return hash_union(obj)
	elseif obj.Type == "tuple" then
		return hash_tuple(obj)
	elseif obj.Type == "table" then
		return hash_table(obj)
	elseif obj.Type == "string" then
		return hash_string(obj)
	elseif obj.Type == "number" then
		return hash_number(obj)
	elseif obj.Type == "any" then
		return "any" -- this is wrong?
	elseif obj.Type == "symbol" then
		return tostring(obj)
	elseif obj.Type == "function" then
		return hash_function(obj)
	end

	error("NYI type " .. obj.Type)
end

return function(obj)
	local res = hash_type(obj)

	if type(res) ~= "string" then
		print(obj)
		error("INVALID RETURN TYPE: " .. type(res))
	end

	return res
end
