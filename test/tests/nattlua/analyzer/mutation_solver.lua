--PLAIN_LUA
local coverage = require("test.helpers.coverage")

local function covered_mutation_solver()
	local f = assert(io.open("nattlua/analyzer/mutation_solver.lua"))
	local code = assert(f:read("*all"))
	f:close()
	return assert(
		loadstring(coverage.Preprocess(code, "mutation_solver"), "@nattlua/analyzer/mutation_solver.lua")
	)()
end

local mutation_solver = covered_mutation_solver()
local LexicalScope = require("nattlua.analyzer.base.lexical_scope").New
local Union = require("nattlua.types.union").Union
local LString = require("nattlua.types.string").LString
local Function = require("nattlua.types.function").Function
local Upvalue = require("nattlua.analyzer.base.upvalue").New
local Any = require("nattlua.types.any").Any

local function test_mutation_solver()
	-- Keep existing tests...
	-- Test mutation removal before else with more certain scopes
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local middle_scope = LexicalScope(root)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetStatement({kind = "if"})
		middle_scope:SetConditionalScope(true)
		middle_scope:SetTruthy(false) -- Make it certain
		middle_scope:SetFalsy(true)
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("if_value")
		local value2 = LString("middle_value")
		local value3 = LString("else_value")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = middle_scope, value = value2},
			{scope = else_scope, value = value3},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(
			result:GetData() == "else_value",
			"Expected else_value but got " .. tostring(result)
		)
	end

	-- Test deeper nested scopes to trigger more Contains() checks
	do
		local root = LexicalScope()
		local scope1 = LexicalScope(root)
		local scope2 = LexicalScope(scope1)
		local scope3 = LexicalScope(scope2)
		local scope4 = LexicalScope(scope3)
		local value1 = LString("value1")
		local value2 = LString("value2")
		local value3 = LString("value3")
		local value4 = LString("value4")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local mutations = {
			{scope = scope1, value = value1},
			{scope = scope2, value = value2},
			{scope = scope3, value = value3},
			{scope = scope4, value = value4},
		}
		local result = mutation_solver(mutations, scope4, upvalue)
		assert(result:GetData() == "value4", "Expected value4 but got " .. tostring(result))
	end

	-- Test union type mutation with mixed function/any/string types
	do
		local root = LexicalScope()
		local scope = LexicalScope(root)
		local func = Function()
		local any = Any()
		local str = LString("value")
		local union = Union({func, any, str})
		local upvalue = Upvalue(str)
		upvalue:SetScope(root)
		local mutations = {
			{scope = scope, value = union},
		}
		local result = mutation_solver(mutations, scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test tracked upvalues with mixed truthy/falsy unions
	do
		local root = LexicalScope()
		local scope1 = LexicalScope(root)
		local scope2 = LexicalScope(scope1)
		scope1:SetConditionalScope(true)
		scope2:SetElseConditionalScope(true)
		scope2:SetConditionalScope(true)
		local value1 = LString("value1")
		local value2 = LString("value2")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local truthy = Union({LString("truthy1"), LString("truthy2")})
		local falsy = Union({LString("falsy1"), LString("falsy2")})
		scope1:SetTrackedUpvalues(
			{
				{
					upvalue = upvalue,
					stack = {{truthy = truthy, falsy = falsy}},
				},
			}
		)
		local mutations = {
			{scope = scope1, value = value1},
			{scope = scope2, value = value2},
		}
		local result = mutation_solver(mutations, scope2, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test conditional scopes with same test conditions
	do
		local root = LexicalScope()
		local scope1 = LexicalScope(root)
		local scope2 = LexicalScope(scope1)
		scope1:SetConditionalScope(true)
		scope2:SetConditionalScope(true)
		scope1:SetStatement({kind = "if"})
		scope2:SetStatement({kind = "if"})
		-- Setup tracking for same conditions
		local test_obj = LString("test")
		scope1:SetTrackedUpvalues({
			{upvalue = test_obj, stack = {{truthy = test_obj, falsy = test_obj}}},
		})
		scope2:SetTrackedUpvalues({
			{upvalue = test_obj, stack = {{truthy = test_obj, falsy = test_obj}}},
		})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local mutations = {
			{scope = scope1, value = value1},
			{scope = scope2, value = value2},
		}
		local result = mutation_solver(mutations, scope2, upvalue)
		assert(result:GetData() == "value2", "Expected value2 but got " .. tostring(result))
	end

	-- Test scopes with mutations from tracking
	do
		local root = LexicalScope()
		local scope1 = LexicalScope(root)
		local scope2 = LexicalScope(scope1)
		scope1:SetConditionalScope(true)
		scope2:SetConditionalScope(true)
		local value1 = LString("value1")
		local value2 = LString("value2")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local mutations = {
			{scope = scope1, value = value1, from_tracking = true},
			{scope = scope2, value = value2, from_tracking = true},
		}
		local result = mutation_solver(mutations, scope2, upvalue)
		assert(result:GetData() == "value2", "Expected value2 but got " .. tostring(result))
	end

	-- Test value type removals
	do
		local root = LexicalScope()
		local scope = LexicalScope(root)
		local str = LString("test")
		local func = Function()
		local any = Any()
		local upvalue = Upvalue(str)
		upvalue:SetScope(root)
		local mutations = {
			{scope = scope, value = str},
			{scope = scope, value = func},
			{scope = scope, value = any},
		}
		local result = mutation_solver(mutations, scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test zero cardinality union handling
	do
		local root = LexicalScope()
		local scope = LexicalScope(root)
		local else_scope = LexicalScope(root)
		scope:SetConditionalScope(true)
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		local value = LString("test")
		local upvalue = Upvalue(value)
		upvalue:SetScope(root)
		-- Set up a tracking stack with empty union
		local empty_union = Union()
		scope:SetTrackedUpvalues(
			{
				{
					upvalue = upvalue,
					stack = {{truthy = value, falsy = empty_union}},
				},
			}
		)
		local mutations = {
			{scope = scope, value = value},
			{scope = else_scope, value = LString("else")},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test belongsToIfStatement cases thoroughly
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local else_if_scope = LexicalScope(root)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetStatement({kind = "if"})
		else_if_scope:SetConditionalScope(true)
		else_if_scope:SetStatement({kind = "if"})
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local value3 = LString("value3")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = else_if_scope, value = value2},
			{scope = else_scope, value = value3},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test removal of redundant mutations before else with certain scopes
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local middle_scope = LexicalScope(root)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetStatement({kind = "if"})
		middle_scope:SetConditionalScope(true)
		middle_scope:SetStatement({kind = "if"})
		middle_scope:SetTruthy(true)
		middle_scope:SetFalsy(false) -- Make it certain
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("if_value")
		local value2 = LString("middle_value")
		local value3 = LString("else_value")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = middle_scope, value = value2},
			{scope = else_scope, value = value3},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(
			result:GetData() == "else_value",
			"Expected else_value but got " .. tostring(result)
		)
	end

	-- Test complex union and value type checking
	do
		local root = LexicalScope()
		local scope1 = LexicalScope(root)
		local scope2 = LexicalScope(root)
		scope1:SetConditionalScope(true)
		scope2:SetConditionalScope(true)
		local str = LString("test")
		local func = Function()
		local any = Any()
		local union1 = Union({str, func})
		local union2 = Union({any})
		local upvalue = Upvalue(str)
		upvalue:SetScope(root)
		-- Test multiple combinations of value types
		local mutations = {
			{scope = scope1, value = str}, -- string
			{scope = scope1, value = func}, -- function
			{scope = scope1, value = union1}, -- union with string and function
			{scope = scope1, value = union2}, -- union with any
			{scope = scope2, value = any}, -- any
		}
		local result = mutation_solver(mutations, scope2, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test complex scope relationships with certain/uncertain states
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local middle_scope = LexicalScope(root)
		local nested_scope = LexicalScope(middle_scope)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetStatement({kind = "if"})
		middle_scope:SetConditionalScope(true)
		middle_scope:SetStatement({kind = "if"})
		middle_scope:SetTruthy(true)
		middle_scope:SetFalsy(false)
		nested_scope:SetConditionalScope(true)
		nested_scope:SetStatement({kind = "if"})
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local value3 = LString("value3")
		local value4 = LString("value4")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = middle_scope, value = value2},
			{scope = nested_scope, value = value3},
			{scope = else_scope, value = value4},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test complete else mutation removal chain
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local middle_scope = LexicalScope(root)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetStatement({kind = "if"})
		if_scope:SetTruthy(true)
		if_scope:SetFalsy(false)
		middle_scope:SetConditionalScope(true)
		middle_scope:SetStatement({kind = "if"})
		middle_scope:SetTruthy(true)
		middle_scope:SetFalsy(false)
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("if_value")
		local value2 = LString("middle_value")
		local value3 = LString("else_value")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		-- Set up a chain of mutations where all previous ones should be removed
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = middle_scope, value = value2},
			{scope = else_scope, value = value3},
		}
		-- This should use the else value as all previous mutations are in certain scopes
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(
			result:GetData() == "else_value",
			"Expected else_value but got " .. tostring(result)
		)
	end

	-- Test falsy/truthy union stacks
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetTruthy(true)
		if_scope:SetFalsy(false)
		if_scope:SetStatement({kind = "if"})
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local value3 = LString("value3")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		-- Set up stack with multiple truthy/falsy values
		if_scope:SetTrackedUpvalues(
			{
				{
					upvalue = upvalue,
					stack = {
						{truthy = value1, falsy = value2},
						{truthy = value2, falsy = value3},
					},
				},
			}
		)
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = else_scope, value = value3},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test multiple conditional scope fallbacks
	do
		local root = LexicalScope()
		local scope1 = LexicalScope(root)
		local scope2 = LexicalScope(scope1)
		local scope3 = LexicalScope(scope2)
		local else_scope = LexicalScope(root)
		scope1:SetConditionalScope(true)
		scope1:SetStatement({kind = "if"})
		scope2:SetConditionalScope(true)
		scope2:SetStatement({kind = "if"})
		scope3:SetConditionalScope(true)
		scope3:SetStatement({kind = "if"})
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local value3 = LString("value3")
		local value4 = LString("value4")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		-- Create a complex chain of mutations through multiple scopes
		local mutations = {
			{scope = scope1, value = value1},
			{scope = scope2, value = value2},
			{scope = scope3, value = value3},
			{scope = else_scope, value = value4},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test redundant mutations in else blocks
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local middle_scope1 = LexicalScope(if_scope)
		local middle_scope2 = LexicalScope(if_scope)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetStatement({kind = "if"})
		middle_scope1:SetConditionalScope(true)
		middle_scope1:SetStatement({kind = "if"})
		middle_scope1:SetTruthy(true)
		middle_scope1:SetFalsy(false) -- Make it certain
		middle_scope2:SetConditionalScope(true)
		middle_scope2:SetStatement({kind = "if"})
		middle_scope2:SetTruthy(true)
		middle_scope2:SetFalsy(false) -- Make it certain
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local value3 = LString("value3")
		local value4 = LString("value4")
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		-- Set up multiple redundant certain mutations
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = middle_scope1, value = value2},
			{scope = middle_scope2, value = value3},
			{scope = else_scope, value = value4},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(result:GetData() == "value4", "Expected value4 but got " .. tostring(result))
	end

	-- Test empty stack cardinality handling
	do
		local root = LexicalScope()
		local scope1 = LexicalScope(root)
		local scope2 = LexicalScope(root)
		scope1:SetConditionalScope(true)
		scope1:SetStatement({kind = "if"})
		scope2:SetConditionalScope(true)
		scope2:SetElseConditionalScope(true)
		scope2:SetStatement({kind = "if"})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local empty_union = Union()
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		-- Set up empty union in the tracking stack
		scope1:SetTrackedUpvalues(
			{
				{
					upvalue = upvalue,
					stack = {{truthy = value1, falsy = empty_union}},
				},
			}
		)
		local mutations = {
			{scope = scope1, value = value1},
			{scope = scope2, value = value2},
		}
		local result = mutation_solver(mutations, scope2, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end

	-- Test conditional with empty stack and multiple mutations
	do
		local root = LexicalScope()
		local if_scope = LexicalScope(root)
		local else_scope = LexicalScope(root)
		if_scope:SetConditionalScope(true)
		if_scope:SetStatement({kind = "if"})
		if_scope:SetTruthy(true)
		if_scope:SetFalsy(true)
		else_scope:SetConditionalScope(true)
		else_scope:SetElseConditionalScope(true)
		else_scope:SetStatement({kind = "if"})
		local value1 = LString("value1")
		local value2 = LString("value2")
		local empty_union = Union()
		local upvalue = Upvalue(value1)
		upvalue:SetScope(root)
		-- Add multiple empty stacks
		if_scope:SetTrackedUpvalues(
			{
				{
					upvalue = upvalue,
					stack = {
						{truthy = empty_union, falsy = empty_union},
						{truthy = empty_union, falsy = value2},
					},
				},
			}
		)
		local mutations = {
			{scope = if_scope, value = value1},
			{scope = else_scope, value = value2},
		}
		local result = mutation_solver(mutations, else_scope, upvalue)
		assert(result ~= nil, "Expected non-nil result")
	end
end

test_mutation_solver()--if ON_EDITOR_SAVE then print(coverage.Collect("mutation_solver")) end
