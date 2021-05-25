local syntax = require("nattlua.syntax.syntax")
local NodeToString = require("nattlua.types.string").NodeToString
local Nil = require("nattlua.types.symbol").Nil
local table = require("table")

local function lookup_value(self, node, env)
	local obj
	local err
	local errors = {}
	local key = NodeToString(node)

	if env == "typesystem" then
		obj, err = self:GetLocalOrEnvironmentValue(key, env)

		if not obj then
			table.insert(errors, err)
			obj, err = self:GetLocalOrEnvironmentValue(key, "runtime")
		end

		if not obj then
			table.insert(errors, err)
			self:Error(node, errors)
			return Nil()
		end
	else
		obj, err = self:GetLocalOrEnvironmentValue(key, env)

		if not obj then
			table.insert(errors, err)
			obj, err = self:GetLocalOrEnvironmentValue(key, "typesystem")
		end

		if not obj then
			if not obj then
				self:Warning(node, err)
			end

			obj = self:GuessTypeFromIdentifier(node, env)
		end
	end

	node.inferred_type = node.inferred_type or obj
	local upvalue = obj:GetUpvalue()

	if upvalue and self.current_statement.checks then
		local checks = self.current_statement.checks[upvalue]

		if checks then
			local val = checks[#checks]

			if val then
				if val.inverted then
					return val:GetFalsyUnion()
				else
					return val:GetTruthyUnion()
				end
			end
		end
	end

	return obj
end

local function is_primitive(val)
	return
		val == "string" or
		val == "number" or
		val == "boolean" or
		val == "true" or
		val == "false" or
		val == "nil"
end

return function(analyzer, node, env)
	local value = node.value.value
	local type = syntax.GetTokenType(node.value)

	-- this means it's the first part of something, either >true<, >foo<.bar, >foo<()
	local standalone_letter = type == "letter" and node.standalone_letter

	if env == "typesystem" and standalone_letter and not node.force_upvalue then
		local current_table = analyzer.current_tables and
			analyzer.current_tables[#analyzer.current_tables]

		if current_table then
			if value == "self" then return current_table end

			if
				analyzer.left_assigned and
				analyzer.left_assigned:GetData() == value and
				not is_primitive(value)
			then
				return current_table
			end
		end

		if value == "any" then
			return analyzer:NewType(node, "any")
		elseif value == "inf" then
			return analyzer:NewType(node, "number", math.huge, true)
		elseif value == "nil" then
			return analyzer:NewType(node, "nil")
		elseif value == "nan" then
			return analyzer:NewType(node, "number", 0 / 0, true)
		elseif is_primitive(value) then
			return analyzer:NewType(node, value)
		end
	end

	if standalone_letter or value == "..." or node.force_upvalue then
		local val = lookup_value(analyzer, node, env)

		if val:GetUpvalue() then
			analyzer:GetScope():AddDependency(val:GetUpvalue())
		end

		return val
	end

	if type == "keyword" then
		if value == "nil" then
			return analyzer:NewType(node, "nil", nil, env == "typesystem")
		elseif value == "true" then
			return analyzer:NewType(node, "boolean", true, true)
		elseif value == "false" then
			return analyzer:NewType(node, "boolean", false, true)
		end
	end

	if type == "number" then
		return analyzer:NewType(node, "number", analyzer:StringToNumber(node, value), true)
	elseif type == "string" then
		if value:sub(1, 1) == "[" then
			local start = value:match("(%[[%=]*%[)")
			return analyzer:NewType(node, "string", value:sub(#start + 1, -#start - 1), true)
		else
			return analyzer:NewType(node, "string", value:sub(2, -2), true)
		end
	elseif type == "letter" then
		return analyzer:NewType(node, "string", value, true)
	end

	analyzer:FatalError("unhandled value type " .. type .. " " .. node:Render())
end
