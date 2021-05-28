
return function(parser)
	local optional_expression_list = require("nattlua.parser.expressions.expression").optional_expression_list
	if not (parser:IsCurrentValue("import") and parser:IsValue("(", 1)) then return end
	local node = parser:Node("expression", "import")
	node.tokens["import"] = parser:ReadValue("import")
	node.tokens["("] = {parser:ReadValue("(")}
	local start = parser:GetCurrentToken()
	node.expressions = optional_expression_list(parser)
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
