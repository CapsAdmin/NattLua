-- Test safe navigation operator parsing
local nl = require("nattlua")

-- Test 1: a?.field
test("safe navigation index expression", function()
	local code = "local x = a?.field"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(result.SyntaxTree, "result should have a syntax tree")
	assert(result.SyntaxTree.statements, "syntax tree should have statements")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	-- The expression should be parsed as a safe navigation index
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_local_assignment", "expected statement_local_assignment")
	assert(stmt.right[1].Type == "expression_binary_operator", "expected expression_binary_operator")
	assert(stmt.right[1].value.sub_type == "?.", "expected ?." .. " operator")
	assert(stmt.right[1].safe_navigation == true, "expected safe_navigation flag")
end)

-- Test 2: a?.[key]
test("safe navigation postfix index expression", function()
	local code = "local x = a?.[\"key\"]"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_local_assignment", "expected statement_local_assignment")
	assert(
		stmt.right[1].Type == "expression_postfix_expression_index",
		"expected expression_postfix_expression_index"
	)
	assert(stmt.right[1].safe_navigation == true, "expected safe_navigation flag")
end)

-- Test 3: f?.(...)
test("safe navigation call expression", function()
	local code = "local x = f?.(1, 2)"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_local_assignment", "expected statement_local_assignment")
	assert(stmt.right[1].Type == "expression_postfix_call", "expected expression_postfix_call")
	assert(stmt.right[1].safe_navigation == true, "expected safe_navigation flag")
end)

-- Test 4: f?."string"
test("safe navigation string call expression", function()
	local code = "local x = f?.\"method\""
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_local_assignment", "expected statement_local_assignment")
	assert(stmt.right[1].Type == "expression_postfix_call", "expected expression_postfix_call")
	assert(stmt.right[1].safe_navigation == true, "expected safe_navigation flag")
end)

-- Test 5: f?.{...}
test("safe navigation table call expression", function()
	local code = "local x = f?.{a = 1}"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_local_assignment", "expected statement_local_assignment")
	assert(stmt.right[1].Type == "expression_postfix_call", "expected expression_postfix_call")
	assert(stmt.right[1].safe_navigation == true, "expected safe_navigation flag")
end)

-- Test 6: obj?.:method(...)
test("safe navigation self call expression", function()
	local code = "local x = obj?.:method(1)"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_local_assignment", "expected statement_local_assignment")
	-- The outer expression is a postfix call (obj?.:method(...))
	assert(stmt.right[1].Type == "expression_postfix_call", "expected expression_postfix_call")
	assert(stmt.right[1].safe_navigation == true, "expected safe_navigation flag")
	-- The inner expression (stmt.right[1].left) should be the binary operator (obj?.:method)
	assert(
		stmt.right[1].left.Type == "expression_binary_operator",
		"expected inner expression_binary_operator"
	)
	assert(stmt.right[1].left.value.sub_type == ":", "expected : operator")
	assert(stmt.right[1].left.safe_navigation == true, "expected safe_navigation flag on inner")
end)

-- Test 7: Chained safe navigation a?.b?.c
test("chained safe navigation", function()
	local code = "local x = a?.b?.c"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_local_assignment", "expected statement_local_assignment")
	-- The outer expression should be a?.b?.c
	assert(stmt.right[1].Type == "expression_binary_operator", "expected expression_binary_operator")
	assert(stmt.right[1].value.sub_type == "?.", "expected ?." .. " operator")
	assert(stmt.right[1].safe_navigation == true, "expected safe_navigation flag on outer")
	-- The inner expression should be a?.b
	assert(
		stmt.right[1].left.Type == "expression_binary_operator",
		"expected inner expression_binary_operator"
	)
	assert(stmt.right[1].left.value.sub_type == "?.", "expected inner ?." .. " operator")
	assert(stmt.right[1].left.safe_navigation == true, "expected safe_navigation flag on inner")
end)

-- Test 8: Safe navigation in assignment a?.field = expr
test("safe navigation in assignment", function()
	local code = "a?.field = 1"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_assignment", "expected statement_assignment")
	assert(
		stmt.left[1].Type == "expression_binary_operator",
		"expected expression_binary_operator on left"
	)
	assert(stmt.left[1].value.sub_type == "?.", "expected ?." .. " operator")
	assert(stmt.left[1].safe_navigation == true, "expected safe_navigation flag")
end)

-- Test 9: Safe navigation in index assignment a?.[key] = expr
test("safe navigation index assignment", function()
	local code = "a?.[\"key\"] = 1"
	local result = assert(nl.Compiler(code):Parse())
	assert(result, "parser should return a result")
	assert(
		#result.SyntaxTree.statements > 0,
		"syntax tree should have at least one statement"
	)
	local stmt = result.SyntaxTree.statements[1]
	assert(stmt.Type == "statement_assignment", "expected statement_assignment")
	assert(
		stmt.left[1].Type == "expression_postfix_expression_index",
		"expected expression_postfix_expression_index on left"
	)
	assert(stmt.left[1].safe_navigation == true, "expected safe_navigation flag")
end)
