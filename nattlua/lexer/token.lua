--ANALYZE
local formating = require("nattlua.other.formating")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("token")
local reverse_escape_string = require("nattlua.other.reverse_escape_string")
local runtime_syntax = require("nattlua." .. "syntax.runtime"--[[# as any]]) -- TODO infinite require token.lua recursion
local typesystem_syntax = require("nattlua." .. "syntax.typesystem"--[[# as any]])
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local tostring = _G.tostring
local table_insert = _G.table.insert
--[[#type META.@Name = "Token"]]
--[[#type META.TokenWhitespaceType = "line_comment" | "multiline_comment" | "comment_escape" | "space"]]
--[[#type META.TokenType = "analyzer_debug_code" | "parser_debug_code" | "letter" | "string" | "number" | "symbol" | "end_of_file" | "shebang" | "unknown" | META.TokenWhitespaceType]]
--[[#type META.@Self = {
	@Name = "Token",
	type = META.TokenType,
	_value = string,
	value = string,
	start = number,
	stop = number,
	string_value = false | string,
	inferred_types = false | List<|any|>,
	potential_idiv = false | boolean,
	parent = false | any,
	whitespace = false | List<|CurrentType<|"table", 1|>|>,
	c_keyword = false | true,
	is_token = true,
}]]
--[[#type META.Token = META.@Self]]

function META:GetRoot()
	if self.parent then return (self.parent--[[# as any]]):GetRoot() end

	return self
end

function META:Copy()
	if false--[[# as true]] then return _--[[# as META.Token]] end -- TODO
	local copy = META.New(self.type, self.value, self.start, self.stop)

	if self.string_value then copy.string_value = self.string_value end

	if self.inferred_types then
		copy.inferred_types = {}

		for i, v in ipairs(self.inferred_types) do
			copy.inferred_types[i] = v
		end
	end

	if self.potential_idiv then copy.potential_idiv = self.potential_idiv end

	if self.whitespace then
		copy.whitespace = {}

		for i, v in ipairs(self.whitespace) do
			copy.whitespace[i] = v:Copy()
		end
	end

	if self.parent then copy.parent = self.parent end

	return copy
end

function META:__tostring()
	return "[token - " .. self.type .. " - " .. formating.QuoteToken(self.value) .. "]"
end

function META:AssociateType(obj)
	self.inferred_types = self.inferred_types or {}
	self.inferred_types[#self.inferred_types + 1] = obj
end

function META:GetAssociatedTypes()
	self.inferred_types = self.inferred_types or {}
	return self.inferred_types
end

function META:GetLastAssociatedType()
	self.inferred_types = self.inferred_types or {}
	return self.inferred_types[#self.inferred_types]
end

function META:FindType()
	local found_parents = {}

	do
		local node = self.parent

		while node and node.parent do
			table_insert(found_parents, node)
			node = node.parent
		end
	end

	local scope

	for _, node in ipairs(found_parents) do
		if node.scope then
			scope = node.scope

			break
		end
	end

	local types = {}

	for _, node in ipairs(found_parents) do
		local found = false

		for _, obj in ipairs(node:GetAssociatedTypes()) do
			if
				(
					obj.Type == "string" or
					obj.Type == "number"
				)
				and
				tostring(obj:GetData()) == self:GetValueString()
			then

			else
				table_insert(types, obj)
				found = true
			end
		end

		if found then break end
	end

	return types, found_parents, scope
end

function META:FindUpvalue()
	local node = self--[[# as any]]

	while node do
		local types = node:GetAssociatedTypes()

		if #types > 0 then
			for i, v in ipairs(types) do
				local upvalue = v:GetUpvalue()

				if upvalue then return upvalue end
			end
		end

		node = node.parent
	end
end

function META:GetStringValue()
	if self.string_value then return self.string_value end

	if self.type == "string" then
		local value = self:GetValueString()

		if value:sub(1, 1) == [["]] or value:sub(1, 1) == [[']] then
			self.string_value = reverse_escape_string(value:sub(2, #value - 1))
			return self.string_value
		elseif value:sub(1, 1) == "[" then
			local start = value:find("[", 2, true)

			if not start then error("start not found") end

			self.string_value = value:sub(start + 1, -start - 1)
			return self.string_value
		end
	end
end

function META:IsUnreachable()--[[#: boolean]]
	local parent = self.parent--[[# as any]]

	while parent do
		if parent.IsUnreachable and parent:IsUnreachable() then return true end

		parent = parent.parent
	end

	return false
end

do
	function META:GetMainType()--[[#: any]]
		if self.FindType then
			local types = self:FindType()
			local obj = types[1]

			if not obj then return end

			if obj.Type == "tuple" and obj:HasOneValue() then
				obj = obj:GetFirstValue()
			elseif obj.Type == "union" and obj:GetCardinality() == 1 then
				obj = obj:GetData()[1]
			end

			return obj
		end
	end

	function META:IsKeyword()--[[#: boolean]]
		local self = self--[[# as any]]

		if self.c_keyword then return true end

		if
			self.parent and
			(
				runtime_syntax:IsNonStandardKeyword(self) or
				typesystem_syntax:IsNonStandardKeyword(self)
			)
			and
			-- check if it's used in a statement, because foo.>>continue<< = true should not highlight as a keyword
			self.parent.is_statement
		then
			return true
		end

		if runtime_syntax:IsKeyword(self) or typesystem_syntax:IsKeyword(self) then
			return true
		end

		if self.parent then
			if
				self.parent.Type == "expression_value" and
				self.parent.parent.Type == "expression_binary_operator" and
				(
					self.parent.parent.value and
					self.parent.parent.value:ValueEquals(".") or
					self.parent.parent.value:ValueEquals(":")
				)
			then
				if self:ValueEquals("@") then return true end
			end
		end

		return false
	end

	function META:IsKeywordValue()--[[#: boolean]]
		local self = self--[[# as any]]

		if runtime_syntax:IsKeywordValue(self) or typesystem_syntax:IsKeywordValue(self) then
			return true
		end

		return false
	end

	function META:IsSymbol()--[[#: boolean]]
		local self = self--[[# as any]]

		-- true, false, nil
		if runtime_syntax:IsKeywordValue(self) or typesystem_syntax:IsKeywordValue(self) then
			return true
		end

		local obj = self:GetMainType()

		if obj then
			if obj.Type == "symbol" then return true end

			if obj.Type == "union" and obj:IsTypeExceptNil("symbol") then
				return true
			end
		end

		return false
	end

	function META:IsOperator()--[[#: boolean]]
		local self = self--[[# as any]]

		if
			self:ValueEquals(".") or
			self:ValueEquals(":") or
			self:ValueEquals("=") or
			self:ValueEquals("or") or
			self:ValueEquals("and") or
			self:ValueEquals("not") or
			runtime_syntax:GetTokenType(self):find("operator", nil, true) or
			typesystem_syntax:GetTokenType(self):find("operator", nil, true)
		then
			return true
		end

		return false
	end

	function META:IsNumber()--[[#: boolean]]
		if self.type == "number" then return true end

		local obj = self:GetMainType()

		if obj then
			if obj.Type == "number" or obj.Type == "range" then return true end

			if
				obj.Type == "union" and
				(
					obj:IsTypeExceptNil("number") or
					obj:IsTypeExceptNil("range")
				)
			then
				return true
			end
		end

		return false
	end

	function META:IsString()--[[#: boolean]]
		if self.type == "string" then return true end

		local obj = self:GetMainType()

		if obj then
			if obj.Type == "string" then return true end

			if obj.Type == "union" and obj:IsTypeExceptNil("string") then
				return true
			end
		end

		return false
	end

	function META:IsAny()--[[#: boolean]]
		local obj = self:GetMainType()

		if obj and obj.Type == "any" then return true end

		return false
	end

	function META:IsFunction()--[[#: boolean]]
		if
			self.type == "letter" and
			self.parent and
			self.parent.Type:find("function", nil, true)
		then

		--return true
		end

		local obj = self:GetMainType()

		if obj then
			if obj.Type == "function" then return true end

			if obj.Type == "union" and obj:IsTypeExceptNil("function") then
				return true
			end

			local parent = obj:GetParent()

			if parent then if obj.Type == "function" then return true -- ?
			end end
		end

		return false
	end

	function META:IsTable()--[[#: boolean]]
		local obj = self:GetMainType()

		if obj and obj.Type == "table" then return true end

		return false
	end

	function META:IsOtherType()--[[#: boolean]]
		if self.parent and self.parent.standalone_letter then
			if self.parent.environment == "typesystem" then return true end

			return false
		end

		if self.parent and self.parent.is_identifier then
			if self.parent.environment == "typesystem" then return true end

			return false
		end

		local obj = self:GetMainType()

		if obj and (obj.Type == "tuple" or (obj.Type == "union" and obj:IsEmpty())) then
			return true
		end

		return false
	end

	function META:DecomposeString()--[[#: string | nil, string | nil, string | nil]]
		if self.type ~= "string" then return end

		local str = self:GetValueString()

		local start = ""
		local stop = ""
		local t = str:sub(1, 1)

		if t == "\"" then
			start = t
			stop = t
		elseif t == "'" then
			start = t
			stop = t
		elseif t == "[" then
			start = assert(str:match("^%[[=]*%["))
			stop = start:gsub("%[", "]")
		else
			error("what? " .. str)
		end

		return str:sub(#start + 1, -#stop - 1), start, stop
	end
end

META.is_token = true

function META:ValueEquals(str)
	return self._value == str
end

function META:ReplaceValue(new_str--[[#: string]])
	self._value = new_str
end

function META:GetValueString()
	return self._value
end

function META.New(
	type--[[#: META.TokenType]],
	value--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]]
)--[[#: META.@Self]]
	return META.NewObject({
		type = type,
		_value = value,
		start = start,
		stop = stop,
	}--[[# as META.@Self]])
end

return META
