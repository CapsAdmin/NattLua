local formating = require("nattlua.other.formating")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("token")
local reverse_escape_string = require("nattlua.other.reverse_escape_string")
local setmetatable = _G.setmetatable
--[[#type META.@Name = "Token"]]
--[[#type META.TokenWhitespaceType = "line_comment" | "multiline_comment" | "comment_escape" | "space"]]
--[[#type META.TokenType = "analyzer_debug_code" | "parser_debug_code" | "letter" | "string" | "number" | "symbol" | "end_of_file" | "shebang" | "unknown" | META.TokenWhitespaceType]]
--[[#type META.@Self = {
	@Name = "Token",
	type = META.TokenType,
	value = string,
	start = number,
	stop = number,
	string_value = nil | string,
	inferred_types = nil | List<|any|>,
	potential_idiv = nil | boolean,
	parent = nil | any,
	whitespace = nil | List<|CurrentType<|"table", 1|>|>,
}]]
--[[#type META.Token = META.@Self]]

function META:GetRoot()
	if self.parent then return (self.parent--[[# as any]]):GetRoot() end

	return self
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
	if false--[[# as true]] then return end

	local found_parents = {}

	do
		local node = self.parent

		while node and node.parent do
			table.insert(found_parents, node)
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
			if obj.Type == "string" and obj:GetData() == self.value then

			elseif obj.Type == "number" and tostring(obj:GetData()) == self.value then

			else
				local exists = false

				-- duplicates of these have been taken care of already
				if
					obj.Type ~= "string" and
					obj.Type ~= "number" and
					obj.Type ~= "symbol" and
					obj.Type ~= "any"
				then
					for i, v in ipairs(types) do
						if v:Equal(obj) then
							exists = true

							break
						end
					end
				end

				if not exists then
					table.insert(types, obj)
					found = true
				end
			end
		end

		if found then break end
	end

	return types, found_parents, scope
end

function META:FindUpvalue()
	if false--[[# as true]] then return end

	local node = self

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

function META:GetSemanticType()
	if false--[[# as true]] then return end

	local runtime_syntax = require("nattlua.syntax.runtime")
	local typesystem_syntax = require("nattlua.syntax.typesystem")
	local Union = require("nattlua.types.union").Union
	local token = self

	if token.parent then
		if token.type == "symbol" and token.parent.kind == "function_signature" then
			return "keyword"
		end

		if
			runtime_syntax:IsNonStandardKeyword(token) or
			typesystem_syntax:IsNonStandardKeyword(token)
		then
			-- check if it's used in a statement, because foo.type should not highlight
			if token.parent and token.parent.type == "statement" then
				return "keyword"
			end
		end
	end

	if runtime_syntax:IsKeywordValue(token) or typesystem_syntax:IsKeywordValue(token) then
		return "type"
	end

	if
		token.value == "." or
		token.value == ":" or
		token.value == "=" or
		token.value == "or" or
		token.value == "and" or
		token.value == "not"
	then
		return "operator"
	end

	if runtime_syntax:IsKeyword(token) or typesystem_syntax:IsKeyword(token) then
		return "keyword"
	end

	if
		runtime_syntax:GetTokenType(token):find("operator", nil, true) or
		typesystem_syntax:GetTokenType(token):find("operator", nil, true)
	then
		return "operator"
	end

	if token.type == "symbol" then return "keyword" end

	do
		local obj
		local types = token:FindType()

		if #types == 1 then obj = types[1] elseif #types > 1 then obj = Union(types) end

		if obj then
			local mods = {}

			if obj:IsLiteral() then table.insert(mods, "readonly") end

			if obj.Type == "union" then
				if obj:IsTypeExceptNil("number") then
					return "number", mods
				elseif obj:IsTypeExceptNil("string") then
					return "string", mods
				elseif obj:IsTypeExceptNil("symbol") then
					return "enumMember", mods
				end

				return "event"
			end

			if obj.Type == "number" then
				return "number", mods
			elseif obj.Type == "string" then
				return "string", mods
			elseif obj.Type == "tuple" or obj.Type == "symbol" then
				return "enumMember", mods
			elseif obj.Type == "any" then
				return "regexp", mods
			end

			if obj.Type == "function" then return "function", mods end

			local parent = obj:GetParent()

			if parent then
				if obj.Type == "function" then
					return "macro", mods
				else
					if obj.Type == "table" then return "class", mods end

					return "property", mods
				end
			end

			if obj.Type == "table" then return "class", mods end
		end
	end

	if token.type == "number" then
		return "number"
	elseif token.type == "string" then
		return "string"
	end

	if token.parent then
		if
			token.parent.kind == "value" and
			token.parent.parent.kind == "binary_operator" and
			(
				token.parent.parent.value and
				token.parent.parent.value.value == "." or
				token.parent.parent.value.value == ":"
			)
		then
			if token.value:sub(1, 1) == "@" then return "decorator" end
		end

		if token.type == "letter" and token.parent.kind:find("function", nil, true) then
			return "function"
		end

		if
			token.parent.kind == "value" and
			token.parent.parent.kind == "binary_operator" and
			(
				token.parent.parent.value and
				token.parent.parent.value.value == "." or
				token.parent.parent.value.value == ":"
			)
		then
			return "property"
		end

		if token.parent.kind == "table_key_value" then return "property" end

		if token.parent.standalone_letter then
			if token.parent.environment == "typesystem" then return "type" end

			if _G[token.value] then return "namespace" end

			return "variable"
		end

		if token.parent.is_identifier then
			if token.parent.environment == "typesystem" then return "typeParameter" end

			return "variable"
		end
	end

	return "comment"
end

function META:GetStringValue()
	if self.string_value then return self.string_value end

	if self.type == "string" then
		local value = self.value

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

function META.New(
	type--[[#: META.TokenType]],
	value--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]]
)--[[#: META.@Self]]
	return setmetatable(
		{
			type = type,
			value = value,
			start = start,
			stop = stop,
		}--[[# as META.@Self]],
		META
	)
end

return META
