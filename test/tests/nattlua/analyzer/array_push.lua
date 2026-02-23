-- Tests for array push pattern: arr[#arr + 1] = value
--
-- Bug: When src[i] returns T | nil (because array indexing with a non-literal
-- index returns T | nil), assigning it to dst[#dst + 1] where dst has a
-- contract type {[number] = T} fails with "T is not a subset of nil".
--
-- The error is on the LEFT side (the index #dst + 1), not the value.
-- The analyzer appears to type the target slot as nil instead of using
-- the array's contract value type T.
--
-- Workaround: use assert() to narrow away nil from src[i].
-- ============================================================
-- PASSING CASES
-- ============================================================
test("push literal to contracted array in function", function()
	analyze[[
		local type T = {x = number}
		local function push(dst: {[number] = T})
			dst[#dst + 1] = {x = 1}
		end
		push({{x = 0} as T})
	]]
end)

test("push typed parameter to contracted array", function()
	analyze[[
		local type T = {x = number}
		local function push(dst: {[number] = T}, val: T)
			dst[#dst + 1] = val
		end
		push({{x = 0} as T}, {x = 1})
	]]
end)

test("push literal in numeric for loop", function()
	analyze[[
		local type T = {x = number}
		local function pushN(dst: {[number] = T}, n: number)
			for i = 1, n do
				dst[#dst + 1] = {x = i}
			end
		end
		pushN({{x = 0} as T}, 3)
	]]
end)

test("push src[literal] to dst (literal index known to exist)", function()
	analyze[[
		local type T = {x = number}
		local function push(dst: {[number] = T}, src: {[number] = T})
			dst[#dst + 1] = src[1]
		end
		push({{x = 0} as T}, {{x = 1} as T})
	]]
end)

test("push assert(src[i]) narrows away nil (workaround)", function()
	analyze[[
		local type T = {x = number}
		local function merge(dst: {[number] = T}, src: {[number] = T})
			for i = 1, #src do
				dst[#dst + 1] = assert(src[i])
			end
		end
		merge({{x = 0} as T}, {{x = 1} as T})
	]]
end)

-- ============================================================
-- FIXED: src[i] in loop no longer returns T | nil when bounded by #src
-- These previously failed with "is not a subset of nil"
-- Fixed by tag-based tracking: #arr tags its result with the source table,
-- the tag carries through for-loop range creation, and table:Get() omits
-- Nil() when the range key is tagged with the same table.
-- ============================================================
-- Minimal reproduction: two contracted arrays, loop copy
test("FIXED: src[i] in loop push to contracted array", function()
	analyze([[
		local type T = {x = number}
		local dst: {[number] = T} = {{x = 0} as T}
		local src: {[number] = T} = {{x = 1} as T}
		for i = 1, #src do
			dst[#dst + 1] = src[i]
		end
	]])
end)

-- Same pattern in a function
test("FIXED: src[i] in function loop push to contracted array", function()
	analyze([[
		local type T = {x = number}
		local function merge(dst: {[number] = T}, src: {[number] = T})
			for i = 1, #src do
				dst[#dst + 1] = src[i]
			end
		end
		merge({{x = 0} as T}, {{x = 1} as T})
	]])
end)

-- With {[number] = any} source
test("FIXED: any source[i] in loop push to contracted array", function()
	analyze([[
		local type T = {x = number}
		local function merge(dst: {[number] = T}, src: {[number] = any})
			for i = 1, #src do
				dst[#dst + 1] = src[i]
			end
		end
		merge({{x = 0} as T}, {{x = 1}})
	]])
end)

-- The zod pattern: helper function called from closure, deep in constructor chain
test("FIXED: helper merge called from constructor closure (DEFERRED CALL)", function()
	analyze([[
		local type Issue = {code = string, message = string}
		local type Payload = {issues = {[number] = Issue}}

		local function mergeIssues(source: {[number] = any}, dest: Payload)
			for i = 1, #source do
				dest.issues[#dest.issues + 1] = source[i]
			end
		end

		local type Internals = {
			parse = nil | function=(Payload)>(Payload),
			def = {[string] = any},
		}

		local type Schema = {
			_zod = Internals,
		}

		local function make_constructor(
			initializer: function=(any, any)>(nil)
		): function=({[string] = any})>(Schema)
			return function(def: {[string] = any}): Schema
				local inst: Schema = {
					_zod = {
						def = def,
					} as Internals,
				}
				initializer(inst, def)
				return inst
			end
		end

		local MySchema = make_constructor(function(inst: any, def: any)
			inst._zod.parse = function(payload: Payload): Payload
				local result: Payload = {
					issues = {{code = "a", message = "b"} as Issue},
				}
				mergeIssues(result.issues, payload)
				return payload
			end
		end)

		local s = MySchema({})
		local p: Payload = {issues = {{code = "x", message = "y"} as Issue}}
		if s._zod.parse then
			s._zod.parse(p)
		end
	]])
end)
