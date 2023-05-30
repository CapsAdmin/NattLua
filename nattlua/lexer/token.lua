local table_pool = require("nattlua.other.table_pool")
local formating = require("nattlua.other.formating")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("token")
local setmetatable = _G.setmetatable
--[[#type META.@Name = "Token"]]
--[[#type META.TokenWhitespaceType = "line_comment" | "multiline_comment" | "comment_escape" | "space"]]
--[[#type META.TokenType = "analyzer_debug_code" | "parser_debug_code" | "letter" | "string" | "number" | "symbol" | "end_of_file" | "shebang" | "discard" | "unknown" | META.TokenWhitespaceType]]
--[[#type META.@Self = {
	@Name = "Token",
	type = META.TokenType,
	value = string,
	start = number,
	stop = number,
	is_whitespace = boolean | nil,
	string_value = nil | string,
	inferred_type = nil | any,
	inferred_types = nil | List<|any|>,
	parent = nil | any,
	whitespace = false | nil | List<|CurrentType<|"table", 1|>|>,
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
	table.insert(self.inferred_types, obj)
end

function META:GetAssociatedTypes()
	return self.inferred_types or {}
end

function META:GetLastAssociatedType()
	return self.inferred_types and self.inferred_types[#self.inferred_types]
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
			if type(obj) ~= "table" then
				print("UH OH", obj, node, "BAD VALUE IN GET TYPES")
			else
				if obj.Type == "string" and obj:GetData() == self.value then

				else
					if obj.Type == "table" then obj = obj:GetMutatedFromScope(scope) end

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
		runtime_syntax:GetTokenType(token):find("operator") or
		typesystem_syntax:GetTokenType(token):find("operator")
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

local new_token

if jit and jit.arch == "arm64" then
	new_token = table_pool(
		function()
			local x = {
				type = "unknown",
				value = "",
				whitespace = false,
				start = 0,
				stop = 0,
			}--[[# as META.@Self]]
			return x
		end,
		100000
	)
else
	new_token = table_pool(
		function()
			local x = {
				type = "unknown",
				value = "",
				whitespace = false,
				start = 0,
				stop = 0,
			}--[[# as META.@Self]]
			return x
		end,
		3105585
	)
end

function META.New(
	type--[[#: META.TokenType]],
	is_whitespace--[[#: boolean]],
	start--[[#: number]],
	stop--[[#: number]]
)--[[#: META.@Self]]
	local tk = new_token()
	tk.type = type
	tk.is_whitespace = is_whitespace
	tk.start = start
	tk.stop = stop
	setmetatable(tk, META)
	return tk
end

return META