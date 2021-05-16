local binary_operator = require("nattlua.analyzer.operators.binary")

return function(analyzer, node, r, env)
	local op = node.value.value
	if op == "++" then return binary_operator(analyzer, {value = {value = "+"}}, r, r, env) end
end
