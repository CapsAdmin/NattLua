local runtime_syntax = require("nattlua.syntax.runtime")
local NodeToString = require("nattlua.types.string").NodeToString
local LNumber = require("nattlua.types.number").LNumber
local LNumberFromString = require("nattlua.types.number").LNumberFromString
local Any = require("nattlua.types.any").Any
local True = require("nattlua.types.symbol").True
local False = require("nattlua.types.symbol").False
local Nil = require("nattlua.types.symbol").Nil
local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Number = require("nattlua.types.number").Number
local Boolean = require("nattlua.types.symbol").Boolean
local table = require("table")

local function lookup_value(self, node)
	local errors = {}
	local key = NodeToString(node)
	local obj, err = self:GetLocalOrGlobalValue(key)

	if self:IsTypesystem() then
		-- we fallback to runtime if we can't find the value in the typesystem
		if not obj then
			table.insert(errors, err)
			self:PushAnalyzerEnvironment("runtime")
			obj, err = self:GetLocalOrGlobalValue(key)
			self:PopAnalyzerEnvironment("runtime")

			-- when in the typesystem we want to see the objects contract, not its runtime value
			if obj and obj:GetContract() then obj = obj:GetContract() end
		end

		if not obj then
			table.insert(errors, err)
			self:Error(node, errors)
			return Nil()
		end
	else
		if not obj or (obj.Type == "symbol" and obj:GetData() == nil) then
			self:PushAnalyzerEnvironment("typesystem")
			local objt, errt = self:GetLocalOrGlobalValue(key)
			self:PopAnalyzerEnvironment()

			if objt then obj, err = objt, errt end
		end

		if not obj then
			self:Warning(node, err)
			obj = Any():SetNode(node)
		end
	end

	return self:GetTrackedUpvalue(obj) or obj
end

local function is_primitive(val)
	return val == "string" or
		val == "number" or
		val == "boolean" or
		val == "true" or
		val == "false" or
		val == "nil"
end

return {
	AnalyzeAtomicValue = function(self, node)
		local value = node.value.value
		local type = runtime_syntax:GetTokenType(node.value)

		if type == "keyword" then
			if value == "nil" then
				return Nil():SetNode(node)
			elseif value == "true" then
				return True():SetNode(node)
			elseif value == "false" then
				return False():SetNode(node)
			end
		end

		-- this means it's the first part of something, either >true<, >foo<.bar, >foo<()
		local standalone_letter = type == "letter" and node.standalone_letter

		if self:IsTypesystem() and standalone_letter and not node.force_upvalue then
			if value == "current_table" then
				return self:GetCurrentType("table")
			elseif value == "current_tuple" then
				return self:GetCurrentType("tuple")
			elseif value == "current_function" then
				return self:GetCurrentType("function")
			elseif value == "current_union" then
				return self:GetCurrentType("union")
			end

			local current_table = self:GetCurrentType("table")

			if current_table then
				if value == "self" then
					return current_table
				elseif
					self.left_assigned and
					self.left_assigned:GetData() == value and
					not is_primitive(value)
				then
					return current_table
				end
			end

			if value == "any" then
				return Any():SetNode(node)
			elseif value == "inf" then
				return LNumber(math.huge):SetNode(node)
			elseif value == "nan" then
				return LNumber(math.abs(0 / 0)):SetNode(node)
			elseif value == "string" then
				return String():SetNode(node)
			elseif value == "number" then
				return Number():SetNode(node)
			elseif value == "boolean" then
				return Boolean():SetNode(node)
			end
		end

		if standalone_letter or value == "..." or node.force_upvalue then
			local val = lookup_value(self, node)

			if val:GetUpvalue() then
				self:GetScope():AddDependency(val:GetUpvalue())
			end

			return val
		end

		if type == "number" then
			local num = LNumberFromString(value)

			if not num then
				self:Error(node, "unable to convert " .. value .. " to number")
				num = Number()
			end

			num:SetNode(node)
			return num
		elseif type == "string" then
			return LString(node.value.string_value):SetNode(node)
		elseif type == "letter" then
			return LString(value):SetNode(node)
		end

		self:FatalError("unhandled value type " .. type .. " " .. node:Render())
	end,
}
