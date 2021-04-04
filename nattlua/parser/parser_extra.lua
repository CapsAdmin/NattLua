local list = require("nattlua.other.list")
return function(META)
	local setmetatable = setmetatable
	local type = type
	local math_huge = math.huge
	local syntax = require("nattlua.syntax.syntax")

	do
		function META:IsDestructureStatement(offset)
			offset = offset or 0
			return
				(self:IsValue("{", offset + 0) and self:IsType("letter", offset + 1)) or
				(self:IsType("letter", offset + 0) and self:IsValue(",", offset + 1) and self:IsValue("{", offset + 2))
		end

		local function read_remaining(self, node)
			if self:IsCurrentType("letter") then
				local val = self:Expression("value")
				val.value = self:ReadTokenLoose()
				node.default = val
				node.default_comma = self:ReadValue(",")
			end

			node.tokens["{"] = self:ReadValue("{")
			node.left = self:ReadIdentifierList()
			node.tokens["}"] = self:ReadValue("}")
			node.tokens["="] = self:ReadValue("=")
			node.right = self:ReadExpression()
		end

		function META:ReadDestructureAssignmentStatement()
			if not self:IsDestructureStatement() then return end
			local node = self:Statement("destructure_assignment")
			read_remaining(self, node)
			return node
		end

		do
			function META:IsLocalDestructureAssignmentStatement()
				if self:IsCurrentValue("local") then
					if self:IsValue("type", 1) then return self:IsDestructureStatement(2) end
					return self:IsDestructureStatement(1)
				end
			end

			function META:ReadLocalDestructureAssignmentStatement()
				if not self:IsLocalDestructureAssignmentStatement() then return end
				local node = self:Statement("local_destructure_assignment")
				node.tokens["local"] = self:ReadValue("local")

				if self:IsCurrentValue("type") then
					node.tokens["type"] = self:ReadValue("type")
					node.environment = "typesystem"
				end

				read_remaining(self, node)
				return node
			end
		end
	end

	do
		function META:ReadLSXStatement()
			return self:ReadLSXExpression(true)
		end

		function META:ReadLSXExpression(statement)
			if not (self:IsCurrentValue("[") and self:IsType("letter", 1)) then return end
			local node = statement and self:Statement("lsx") or self:Expression("lsx")
			node.tokens["["] = self:ReadValue("[")
			node.tag = self:ReadType("letter")
			local props = list.new()

			while true do
				if self:IsCurrentType("letter") and self:IsValue("=", 1) then
					local key = self:ReadType("letter")
					self:ReadValue("=")
					local val = self:ReadExpectExpression()
					props:insert({key = key, val = val,})
				elseif self:IsCurrentValue("...") then
					self:ReadTokenLoose() -- !
                    props:insert({
						val = self:ReadExpression(nil, true),
						spread = true,
					})
				else
					break
				end
			end

			node.tokens["]"] = self:ReadValue("]")
			node.props = props

			if self:IsCurrentValue("{") then
				node.tokens["{"] = self:ReadValue("{")
				node.statements = self:ReadStatements({["}"] = true})
				node.tokens["}"] = self:ReadValue("}")
			end

			return node
		end
	end
end
