local Binary = require("nattlua.analyzer.operators.binary").Binary
return
	{
		Postfix = function(analyzer, node, r)
			local op = node.value.value
			if op == "++" then return Binary(analyzer, {value = {value = "+"}}, r, r) end
		end,
	}
