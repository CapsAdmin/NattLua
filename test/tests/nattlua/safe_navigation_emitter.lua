-- Test safe navigation operator emission
local nl = require("nattlua")

-- Test 1: a?.field emits directly
test("safe navigation index expression emission", function()
	local code = "local x = a?.field"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
	assert(result:find("a", nil, true), "expected 'a' in output")
	assert(result:find("field", nil, true), "expected 'field' in output")
end)

-- Test 2: a?.[key] emits directly
test("safe navigation postfix index expression emission", function()
	local code = "local x = a?.[\"key\"]"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
	assert(result:find("[", nil, true), "expected '[' in output")
	assert(result:find("]", nil, true), "expected ']' in output")
end)

-- Test 3: f?.(...) emits directly
test("safe navigation call expression emission", function()
	local code = "local x = f?.(1, 2)"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
	assert(result:find("(", nil, true), "expected '(' in output")
	assert(result:find(")", nil, true), "expected ')' in output")
end)

-- Test 4: f?."string" emits directly
test("safe navigation string call expression emission", function()
	local code = "local x = f?.\"method\""
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
end)

-- Test 5: f?.{...} emits directly
test("safe navigation table call expression emission", function()
	local code = "local x = f?.{a = 1}"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
end)

-- Test 6: obj?.:method(...) emits directly
test("safe navigation self call expression emission", function()
	local code = "local x = obj?.:method(1)"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
	assert(result:find(":", nil, true), "expected ':' in output")
end)

-- Test 7: Chained safe navigation a?.b?.c emits directly
test("chained safe navigation emission", function()
	local code = "local x = a?.b?.c"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	-- Should have two ?." operators
	local count = 0
	local pos = 1

	while true do
		pos = result:find("?.", pos, true)

		if not pos then break end

		count = count + 1
		pos = pos + 1
	end

	assert(count == 2, "expected two ?." .. " operators in output, got " .. count)
end)

-- Test 8: Safe navigation in assignment emits directly
test("safe navigation assignment emission", function()
	local code = "a?.field = 1"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
	assert(result:find("=", nil, true), "expected '=' in output")
end)

-- Test 9: Safe navigation with regular navigation mixed
test("mixed safe and regular navigation", function()
	local code = "local x = a.b?.c"
	local result = nl.Compiler(code):Emit()
	assert(result, "emitter should return a result")
	assert(result:find(".", nil, true), "expected '.' in output")
	assert(result:find("?.", nil, true), "expected ?." .. " in output")
end)
