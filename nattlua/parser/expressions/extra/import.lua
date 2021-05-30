return
	{
		ReadImport = function(parser)
			local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
			local ReadExpression = require("nattlua.parser.expressions.expression").ReadExpression
			if not (parser:IsValue("import") and parser:IsValue("(", 1)) then return end
			local node = parser:Node("expression", "import")
			node.tokens["import"] = parser:ExpectValue("import")
			node.tokens["("] = {parser:ExpectValue("(")}
			local start = parser:GetToken()
			node.expressions = ReadMultipleValues(parser, nil, ReadExpression, 0)
			local root = parser.config.path and parser.config.path:match("(.+/)") or ""
			node.path = root .. node.expressions[1].value.value:sub(2, -2)
			local nl = require("nattlua")
			local root, err = nl.ParseFile(parser:ResolvePath(node.path), parser.root)

			if not root then
				parser:Error("error importing file: $1", start, start, err)
			end

			node.root = root.SyntaxTree
			node.analyzer = root
			node.tokens[")"] = {parser:ExpectValue(")")}
			parser.root.imports = parser.root.imports or {}
			table.insert(parser.root.imports, node)
			return node
		end,
	}
