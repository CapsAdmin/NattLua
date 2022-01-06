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
			if obj and obj:GetContract() then 
				obj = obj:GetContract() 
			end
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
			if objt then
				obj, err = objt, errt
			end
		end

		if not obj then
			self:Warning(node, err)
			obj = Any():SetNode(node)
		end
	end

	node.inferred_type = node.inferred_type or obj
	local upvalue = obj:GetUpvalue()

	if upvalue and upvalue.exp_stack then
		if self:IsTruthyExpressionContext() then
			return upvalue.exp_stack[#upvalue.exp_stack].truthy:SetUpvalue(upvalue)
		end
		if self:IsFalsyExpressionContext() then
			return upvalue.exp_stack[#upvalue.exp_stack].falsy:SetUpvalue(upvalue)
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

return
	{
		AnalyzeAtomicValue = function(analyzer, node)
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

			if analyzer:IsTypesystem() and standalone_letter and not node.force_upvalue then
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
				local val = lookup_value(analyzer, node)

				if val:GetUpvalue() then
					analyzer:GetScope():AddDependency(val:GetUpvalue())
				end

				return val
			end

			if type == "number" then
				local num = LNumberFromString(value)

				if not num then
					analyzer:Error(node, "unable to convert " .. value .. " to number")
					num = Number()
				end

				num:SetNode(node)
				return num
			elseif type == "string" then
				return LString(node.value.string_value):SetNode(node)
			elseif type == "letter" then
				return LString(value):SetNode(node)
			end

			analyzer:FatalError("unhandled value type " .. type .. " " .. node:Render())
		end,
	}
