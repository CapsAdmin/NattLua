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
