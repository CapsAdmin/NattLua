local table = require("table")

return {ReadRoot = function(parser) 
	local node = parser:Node("statement", "root")
	parser.root = parser.config and parser.config.root or node
	local shebang

	if parser:IsCurrentType("shebang") then
		shebang = parser:Node("statement", "shebang")
		shebang.tokens["shebang"] = parser:ReadType("shebang")
	end

	node.statements = parser:ReadNodes()

	if shebang then
		table.insert(node.statements, 1, shebang)
	end

	if parser:IsCurrentType("end_of_file") then
		local eof = parser:Node("statement", "end_of_file")
		eof.tokens["end_of_file"] = parser.tokens[#parser.tokens]
		table.insert(node.statements, eof)
	end

	return node:End()
end}