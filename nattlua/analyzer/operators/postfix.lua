local Binary = require("nattlua.analyzer.operators.binary").Binary
return
	{
		Postfix = function(self, node, r)
			local op = node.value.value
			if op == "++" then return Binary(self, {value = {value = "+"}}, r, r) end
		end,
	}
