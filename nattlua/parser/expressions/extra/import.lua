return function(parser)
	if not (parser:IsCurrentValue("import") and parser:IsValue("(", 1)) then return end
	local node = parser:Expression("import")
	node.tokens["import"] = parser:ReadValue("import")
	node.tokens["("] = {parser:ReadValue("(")}
	local start = parser:GetCurrentToken()
	node.expressions = parser:ReadExpressionList()
	local root = parser.config.path and parser.config.path:match("(.+/)") or ""
	node.path = root .. node.expressions[1].value.value:sub(2, -2)
	local nl = require("nattlua")
	local root, err = nl.ParseFile(parser:ResolvePath(node.path), parser.root)

	if not root then
		parser:Error("error importing file: $1", start, start, err)
	end

	node.root = root.SyntaxTree
	node.analyzer = root
	node.tokens[")"] = {parser:ReadValue(")")}
	parser.root.imports = parser.root.imports or {}
	table.insert(parser.root.imports, node)
	return node
end
