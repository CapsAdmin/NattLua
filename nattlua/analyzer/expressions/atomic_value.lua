local syntax = require("nattlua.syntax.syntax")
local types = require("nattlua.types.types")
return function(META)
	function META:LookupValue(node, env)
		local obj
		local err
		local errors = {}

		if env == "typesystem" then
			obj, err = self:GetLocalOrEnvironmentValue(node, env)

			if not obj then
				table.insert(errors, err)
				obj, err = self:GetLocalOrEnvironmentValue(node, "runtime")
			end

			if not obj then
				table.insert(errors, err)
				self:Error(node, errors)
				return types.Nil()
			end
		else
			obj, err = self:GetLocalOrEnvironmentValue(node, env)

			if not obj then
				table.insert(errors, err)
				obj, err = self:GetLocalOrEnvironmentValue(node, "typesystem")
			end

			if not obj then
				if not obj then
					self:Warning(node, err)
				end

				obj = self:GuessTypeFromIdentifier(node, env)
			end
		end

		node.inferred_type = node.inferred_type or obj
		local upvalue = obj.upvalue

		if upvalue and self.current_statement.checks then
			local checks = self.current_statement.checks[upvalue]

			if checks then
				local val = checks[#checks]

				if val then
					if val.inverted then
						return val.falsy_union
					else
						return val.truthy_union
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

	function META:AnalyzeAtomicValueExpression(node, env)
		local value = node.value.value
		local type = syntax.GetTokenType(node.value)

        -- this means it's the first part of something, either >true<, >foo<.bar, >foo<()
        local standalone_letter = type == "letter" and node.standalone_letter

		if env == "typesystem" and standalone_letter and not node.force_upvalue then
			local current_table = self.current_tables and self.current_tables[#self.current_tables]

			if current_table then
				if value == "self" then return current_table end

				if
					self.left_assigned and
					self.left_assigned.kind == "value" and
					self.left_assigned.value.value == value and
					not is_primitive(value)
				then
					return current_table
				end
			end

			if value == "any" then
				return self:NewType(node, "any")
			elseif value == "inf" then
				return self:NewType(node, "number", math.huge, true)
			elseif value == "nil" then
				return self:NewType(node, "nil")
			elseif value == "nan" then
				return self:NewType(node, "number", 0 / 0, true)
			elseif is_primitive(value) then
				return self:NewType(node, value)
			end
		end

		if standalone_letter or value == "..." or node.force_upvalue then
			local val = self:LookupValue(node, env)

			if val.upvalue then
				self:GetScope():AddDependency(val.upvalue)
			end

			return val
		end

		if type == "keyword" then
			if value == "nil" then
				return self:NewType(node, "nil", nil, env == "typesystem")
			elseif value == "true" then
				return self:NewType(node, "boolean", true, true)
			elseif value == "false" then
				return self:NewType(node, "boolean", false, true)
			end
		end

		if type == "number" then
			return self:NewType(node, "number", self:StringToNumber(node, value), true)
		elseif type == "string" then
			if value:sub(1, 1) == "[" then
				local start = value:match("(%[[%=]*%[)")
				return self:NewType(node, "string", value:sub(#start + 1, -#start - 1), true)
			else
				return self:NewType(node, "string", value:sub(2, -2), true)
			end
		elseif type == "letter" then
			return self:NewType(node, "string", value, true)
		end

		self:FatalError("unhandled value type " .. type .. " " .. node:Render())
	end
end
