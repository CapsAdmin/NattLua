local ipairs = ipairs
return function(analyzer, node, env)
	local list = analyzer:NewType(node, "list", nil, env == "typesystem")

	for _, node in ipairs(node.expressions) do
		local val = analyzer:AnalyzeExpression(node, env)
		list:Insert(val)
	end

	if node.left then
		list.ElementType = analyzer:AnalyzeExpression(node.left, env)
	end

	return list
end
