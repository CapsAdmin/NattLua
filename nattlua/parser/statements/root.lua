local table = require("table")

return {ReadRoot = function(parser) 
	local node = parser:Node("statement", "root")
	parser.root = parser.config and parser.config.root or node
	local shebang

	if parser:IsType("shebang") then
		shebang = parser:Node("statement", "shebang")
		shebang.tokens["shebang"] = parser:ExpectType("shebang")
		shebang:End()

		node.tokens["shebang"] = shebang.tokens["shebang"]
	end

	node.statements = parser:ReadNodes()

	if shebang then
		table.insert(node.statements, 1, shebang)
	end

	if parser:IsType("end_of_file") then
		local eof = parser:Node("statement", "end_of_file")
		eof.tokens["end_of_file"] = parser.tokens[#parser.tokens]
		eof:End()
		table.insert(node.statements, eof)

		node.tokens["eof"] = eof.tokens["end_of_file"]
	end

	return node:End()
end}