local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
local ReadIdentifier = require("nattlua.parser.expressions.identifier")
return function(parser)
	if not (parser:IsCurrentValue("import") and not parser:IsValue("(", 1)) then return end
	local node = parser:Statement("import")
	node.tokens["import"] = parser:ReadValue("import")
	node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
	node.tokens["from"] = parser:ReadValue("from")
	local start = parser:GetCurrentToken()
	node.expressions = parser:ReadExpressionList()
	local root = parser.config.path:match("(.+/)")
	node.path = root .. node.expressions[1].value.value:sub(2, -2)
	local nl = require("nattlua")
	local root, err = nl.ParseFile(node.path, parser.root).SyntaxTree

	if not root then
		parser:Error("error importing file: $1", start, start, err)
	end

	node.root = root
	parser.root.imports = parser.root.imports or {}
	table.insert(parser.root.imports, node)
	return node
end
