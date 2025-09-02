local nl = require("nattlua")
local table_print = require("nattlua.other.table_print").print
local util = require("examples.util")
local paths = util.GetFilesRecursively("./nattlua")
local stats = {
	tokens = 0,
	locals = 0,
	expressions = {},
	statements = {},
	identifiers = {},
}

for _, path in ipairs(paths) do
	local c = nl.File(path, {skip_import = false})
	local tokens = c:Lex().Tokens
	stats.tokens = stats.tokens + #tokens

	for _, token in ipairs(tokens) do
		if token.type == "letter" then
			stats.identifiers[token.value] = (stats.identifiers[token.value] or 0) + 1
		end
	end

	local list = {}
	c.OnPreCreateNode = function(_, node)
		table.insert(list, node)
	end
	c:Parse()

	for _, node in ipairs(list) do
		if node.Type == "statement_local_function" then
			stats.locals = stats.locals + 1
		end

		if node.Type == "statement_local_assignment" then
			stats.locals = stats.locals + #node.left
		end

		if node.Type == "statement_generic_for" then
			stats.locals = stats.locals + #node.identifiers
		end

		if node.Type == "statement_numeric_for" then stats.locals = stats.locals + 1 end

		if node.is_expression then
			stats.expressions[node.Type] = (stats.expressions[node.Type] or 0) + 1
		else
			stats.statements[node.Type] = (stats.statements[node.Type] or 0) + 1
		end
	end
end

table_print(stats)
