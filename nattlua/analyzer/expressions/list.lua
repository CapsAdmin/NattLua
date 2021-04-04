local types = require("nattlua.types.types")
return function(META)
	function META:AnalyzeListExpression(node, env)
		local list = self:NewType(node, "list", nil, env == "typesystem")

		for _, node in ipairs(node.expressions) do
			local val = self:AnalyzeExpression(node, env)
			list:Insert(val)
		end

		if node.left then
			list.ElementType = self:AnalyzeExpression(node.left, env)
		end

		return list
	end
end
