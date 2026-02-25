local runtime_syntax = require("nattlua.syntax.runtime")
local ConstString = require("nattlua.types.string").ConstString
local LNumber = require("nattlua.types.number").LNumber
local LNumberFromString = require("nattlua.types.number").LNumberFromString
local Any = require("nattlua.types.any").Any
local True = require("nattlua.types.symbol").True
local False = require("nattlua.types.symbol").False
local Nil = require("nattlua.types.symbol").Nil
local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Number = require("nattlua.types.number").Number
local Boolean = require("nattlua.types.union").Boolean
local Deferred = require("nattlua.types.deferred").Deferred
local table = _G.table
local math_abs = math.abs
local math_huge = math.huge
local error_messages = require("nattlua.error_messages")

local function lookup_value(self, tk)
	local errors = {}
	local key = ConstString(tk:GetValueString())
	local upvalue = self:FindLocalUpvalue(key)

	if upvalue then tk:AssociateType(upvalue) end

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
			self:Error(errors)
			return Nil()
		end
	else
		if not obj or (obj.Type == "symbol" and obj:IsNil()) then
			self:PushAnalyzerEnvironment("typesystem")
			local objt, errt = self:GetLocalOrGlobalValue(key)
			self:PopAnalyzerEnvironment()

			if objt then obj, err = objt, errt end
		end

		if not obj then
			if self.config.allow_global_lookup == true then
				self:Warning(err)
			else
				self:Error(err)
			end

			obj = Any()
		end
	end

	local obj = self:GetTrackedUpvalue(obj) or obj

	if obj:GetUpvalue() then self:GetScope():AddDependency(obj:GetUpvalue()) end

	return obj
end

local function is_primitive(tk)
	return tk.sub_type == (
			"string"
		)
		or
		tk.sub_type == (
			"number"
		)
		or
		tk.sub_type == (
			"boolean"
		)
		or
		tk.sub_type == (
			"true"
		)
		or
		tk.sub_type == (
			"false"
		)
		or
		tk.sub_type == (
			"nil"
		)
end

return {
	LookupValue = lookup_value,
	AnalyzeAtomicValue = function(self, node)
		local tk = node.value

		if tk.sub_type == "nil" then
			return Nil()
		elseif tk.sub_type == "true" then
			return True()
		elseif tk.sub_type == "false" then
			return False()
		elseif tk.type == "number" then
			local str = tk:GetValueString()
			local num = LNumberFromString(str)

			if not num then
				self:Error(error_messages.invalid_number(str))
				num = Number()
			end

			return num
		elseif tk.type == "string" then
			return LString(tk:GetStringValue())
		end

		if node.force_upvalue then
			return lookup_value(self, tk)
		elseif tk.sub_type == "..." then
			return lookup_value(self, tk)
		elseif tk.type == "letter" then
			if node.standalone_letter then
				-- standalone_letter means it's the first part of something, either >true<, >foo<.bar, >foo<()
				if self:IsTypesystem() then
					local current_table = self:GetCurrentTypeTable()

					if current_table then
						if tk.sub_type == "self" then
							return current_table
						elseif
							self.left_assigned and
							self.left_assigned.Type == "string" and
							tk:ValueEquals(self.left_assigned:GetData()) and
							not is_primitive(tk)
						then
							return current_table
						end
					end

					if tk.sub_type == ("any") then
						return Any()
					elseif tk.sub_type == ("inf") then
						return LNumber(math_huge)
					elseif tk.sub_type == ("nan") then
						return LNumber(math_abs(0 / 0))
					elseif tk.sub_type == ("string") then
						return String()
					elseif tk.sub_type == ("number") then
						return Number()
					elseif tk.sub_type == ("boolean") then
						return Boolean()
					elseif tk:ValueEquals("deferred") then
						return Deferred()
					end
				end

				return lookup_value(self, tk)
			else
				return ConstString(tk:GetValueString())
			end
		end

		self:FatalError("unhandled value type " .. type .. " " .. node:Render())
	end,
}
