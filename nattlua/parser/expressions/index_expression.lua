local syntax = require("nattlua.syntax.syntax")
return
	{
		ReadIndexExpression = function(parser)
			if not syntax.IsValue(parser:GetToken()) then return end
			local node = parser:Node("expression", "value"):Store("value", parser:ReadToken()):End()
			local first = node

			while parser:IsValue(".") or parser:IsValue(":") do
				local left = node
				local self_call = parser:IsValue(":")
				node = parser:Node("expression", "binary_operator")
				node.value = parser:ReadToken()
				node.right = parser:Node("expression", "value"):Store("value", parser:ReadType("letter")):End()
				node.left = left
				node:End()
				node.right.self_call = self_call
			end

			first.standalone_letter = node
			return node
		end,
	}
