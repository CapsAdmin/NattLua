local Binary = require("nattlua.analyzer.operators.binary").Binary
return
	{
		Postfix = function(analyzer, node, r, env)
			local op = node.value.value
			if op == "++" then return Binary(analyzer, {value = {value = "+"}}, r, r, env) end
		end,
	}
