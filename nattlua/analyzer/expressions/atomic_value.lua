local syntax = require("nattlua.syntax.syntax")
local NodeToString = require("nattlua.types.string").NodeToString
local LNumber = require("nattlua.types.number").LNumber
local Any = require("nattlua.types.any").Any
local True = require("nattlua.types.symbol").True
local False = require("nattlua.types.symbol").False
local Nil = require("nattlua.types.symbol").Nil
local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Number = require("nattlua.types.number").Number
local Boolean = require("nattlua.types.symbol").Boolean
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
			return Any():SetNode(node)
		elseif value == "inf" then
			return LNumber(math.huge):SetNode(node)
		elseif value == "nil" then
			return Nil():SetNode(node)
		elseif value == "nan" then
			return LNumber(0 / 0):SetNode(node)
		elseif value == "string" then
			return String():SetNode(node)
		elseif value == "number" then
			return Number():SetNode(node)
		elseif value == "boolean" then
			return Boolean():SetNode(node)
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
			return Nil():SetNode(node)
		elseif value == "true" then
			return True():SetNode(node)
		elseif value == "false" then
			return False():SetNode(node)
		end
	end

	if type == "number" then
		return LNumber(analyzer:StringToNumber(node, value)):SetNode(node)
	elseif type == "string" then
		if value:sub(1, 1) == "[" then
			local start = value:match("(%[[%=]*%[)")
			return LString(value:sub(#start + 1, -#start - 1)):SetNode(node)
		else
			return LString(value:sub(2, -2)):SetNode(node)
		end
	elseif type == "letter" then
		return LString(value):SetNode(node)
	end

	analyzer:FatalError("unhandled value type " .. type .. " " .. node:Render())
end
