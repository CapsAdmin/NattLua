local shared = require("nattlua.types.shared")
local S = function(code)
	local res = select(3, analyze(code))

	if res.Type == "tuple" then return res:Unpack() end

	return res
end
local ST = function(code)
	local res = select(3, analyze(code))
	return res
end
local X = function(code)
	return S("return " .. code)
end

local function equal(a, b)
	local ok1 = a:GetHash() == b:GetHash()
	local ok2, reason = shared.Equal(a, b)

	if ok1 ~= ok2 then
		print("hash mismatch with equal:")
		print("a b hash:")
		print(a:GetHash())
		print(b:GetHash())
		print("a b types:")
		print(a)
		print(b)
		print("a == b ? ", ok2, reason)
		error("")
	end

	return ok1
end

-- Test cases covering all scenarios
do
	test("basic table equality", function()
		local a = X("{1, 2, 3}")
		local b = X("{1, 2, 3}")
		assert(equal(a, b))
	end)

	test("", function()
		local a = X("{[Any()] = Any()}")
		local b = X("{}")
		assert(not equal(a, b))
	end)

	test("", function()
		local a = X("_ as { [number] = string }")
		local b = X("_ as { [1] = string }")
		assert(not equal(a, b))
	end)

	test("number ranges", function()
		local a = X("_ as 0..inf")
		local b = X("_ as 1..inf")
		local ok, reason = equal(a, b)
		assert(not ok, reason)
	end)

	test("different table values", function()
		local a = X("{1, 2, 3}")
		local b = X("{1, 2, 4}")
		local equal, reason = equal(a, b)
		assert(not equal, reason)
	end)

	test("nested tables", function()
		local a = X("{1, 2, {3, 4}}")
		local b = X("{1, 2, {3, 4}}")
		assert(equal(a, b))
	end)

	test("different nested values", function()
		local a = X("{1, 2, {3, 4}}")
		local b = X("{1, 2, {3, 5}}")
		local equal, reason = equal(a, b)
		assert(not equal, reason)
	end)

	test("self-references", function()
		local a, b = S[[
            local a = {}
		    a.test = a
		    
            local b = {}
		    b.test = b 
            
            return a, b
        ]]
		assert(equal(a, b))
	end)

	test("cross-references", function()
		local a, b = S[[
            local a = {}
            local b = {}
            a.test = b
            b.test = a

            return a, b
        ]]
		assert(equal(a, b))
	end)

	test("simple metatables", function()
		local a, b = S[[
            local mt = {
                __index = function(s, k)
                    return 1
                end,
            }
            local a = {}
            local b = {}
            setmetatable(a, mt)
            setmetatable(b, mt)

            return a, b
        ]]
		assert(equal(a, b))
	end)

	test("different metatables", function()
		do
			return
		end

		local a, b = S[[
            local mt_a = {
				__index = function(s, k)
					return 1
				end,
			}
			local mt_b = {
				__index = function(s, k)
					return 2
				end,
			}
			local a = {}
			local b = {}
			setmetatable(a, mt_a)
			setmetatable(b, mt_b)

            return a, b
        ]]
		local equal, reason = equal(a, b)
		assert(not equal, reason)
	end)

	test("metatable with self-reference", function()
		local a, b = S[[
            local a = {}
            local mt_a = {__index = a}
            setmetatable(a, mt_a)
            local b = {}
            local mt_b = {__index = b}
            setmetatable(b, mt_b)
            return a, b
        ]]
		assert(equal(a, b))
	end)

	test("complex nested structure", function()
		local a = X[[{
			x = 1,
			y = {
				z = 3,
				w = {v = 5},
			},
		}]]
		local b = X[[{
			x = 1,
			y = {
				z = 3,
				w = {v = 5},
			},
		}]]
		assert(equal(a, b))
	end)

	test("mixed key types", function()
		local a = X[[{
				[1] = "one",
				["two"] = 2,
				[true] = false,
			}]]
		local b = X[[{
				[1] = "one",
				["two"] = 2,
				[true] = false,
			}]]
		assert(equal(a, b))
	end)

	test("tables as keys", function()
		local a, b = S[[
            local key1 = {x = 1, y = 2}
			local key2 = {x = 1, y = 2}
			local a = {}
			local b = {}
			a[key1] = "value"
			b[key2] = "value"
            return a, b]]
		assert(equal(a, b))
	end)

	test("Complex self-references", function()
		local a, b = S[[
			local a = {x = 1}
			local b = {x = 1}
			a.self = a
			a.other = b
			b.self = b
			b.other = a
            return a, b]]
		assert(equal(a, b))
	end)

	test("Array with table elements", function()
		local a = X("{{1, 2}, {3, 4}}")
		local b = X("{{1, 2}, {3, 4}}")
		assert(equal(a, b))
	end)

	test("Different order", function()
		local a = X("{c = 3, b = 2, a = 1}")
		local b = X("{a = 1, b = 2, c = 3}")
		assert(equal(a, b))
	end)

	test("Circular metatables", function()
		local a, b = S[[
            local a = {}
			local b = {}
			local mt_a = {parent = a}
			local mt_b = {parent = b}
			setmetatable(a, mt_a)
			setmetatable(b, mt_b)
            return a,b
            ]]
		assert(equal(a, b))
	end)

	test("Deep nested self-references", function()
		local a, b = S[[
			local a = {level1 = {}}
			a.level1.back = a
			local b = {level1 = {}}
			b.level1.back = b
            return a, b]]
		assert(equal(a, b))
	end)

	test("Metatable inheritance", function()
		local a, b = S[[
			local base_mt = {
				__add = function(a, b)
					return a.value + b.value
				end,
			}
			local a_proto = {value = 0}
			setmetatable(a_proto, base_mt)
			local b_proto = {value = 0}
			setmetatable(b_proto, base_mt)
			local a = {value = 5}
			setmetatable(a, {__index = a_proto})
			local b = {value = 5}
			setmetatable(b, {__index = b_proto})
            return a, b
            ]]
		assert(equal(a, b))
	end)

	test("Three-way circular references", function()
		-- First set
		local a, b = S[[
		local a1 = {name = "node1"}
		local a2 = {name = "node2"}
		local a3 = {name = "node3"}
		a1.next = a2
		a2.next = a3
		a3.next = a1
		-- Second set
		local b1 = {name = "node1"}
		local b2 = {name = "node2"}
		local b3 = {name = "node3"}
		b1.next = b2
		b2.next = b3
		b3.next = b1
        return a1, b1
        ]]
		assert(equal(a, b))
	end)

	test("Four-way circular references", function()
		local a, b = S[[
		-- First set
		local a1 = {name = "node1"}
		local a2 = {name = "node2"}
		local a3 = {name = "node3"}
		local a4 = {name = "node4"}
		a1.next = a2
		a2.next = a3
		a3.next = a4
		a4.next = a1
		-- Second set
		local b1 = {name = "node1"}
		local b2 = {name = "node2"}
		local b3 = {name = "node3"}
		local b4 = {name = "node4"}
		b1.next = b2
		b2.next = b3
		b3.next = b4
		b4.next = b1
        return a1, b1
        ]]
		assert(equal(a, b))
	end)

	test("Diamond pattern references", function()
		local a, b = S[[
		-- First diamond
		local a_top = {name = "top"}
		local a_left = {name = "left"}
		local a_right = {name = "right"}
		local a_bottom = {name = "bottom"}
		a_top.left = a_left
		a_top.right = a_right
		a_left.bottom = a_bottom
		a_right.bottom = a_bottom
		a_bottom.top = a_top
		-- Second diamond
		local b_top = {name = "top"}
		local b_left = {name = "left"}
		local b_right = {name = "right"}
		local b_bottom = {name = "bottom"}
		b_top.left = b_left
		b_top.right = b_right
		b_left.bottom = b_bottom
		b_right.bottom = b_bottom
		b_bottom.top = b_top
        return a_top, b_top]]
		assert(equal(a, b))
	end)

	test("Complex graph with cross-references", function()
		local a, b = S[[

		-- First graph
		local a_nodes = {}

		for i = 1, 5 do
			a_nodes[i] = {id = i, connections = {}}
		end

		-- Create connections (edges)
		table.insert(a_nodes[1].connections, a_nodes[2])
		table.insert(a_nodes[1].connections, a_nodes[3])
		table.insert(a_nodes[2].connections, a_nodes[3])
		table.insert(a_nodes[2].connections, a_nodes[4])
		table.insert(a_nodes[3].connections, a_nodes[5])
		table.insert(a_nodes[4].connections, a_nodes[5])
		table.insert(a_nodes[5].connections, a_nodes[1]) -- Circular dependency
		-- Second graph
		local b_nodes = {}

		for i = 1, 5 do
			b_nodes[i] = {id = i, connections = {}}
		end

		-- Create identical connections
		table.insert(b_nodes[1].connections, b_nodes[2])
		table.insert(b_nodes[1].connections, b_nodes[3])
		table.insert(b_nodes[2].connections, b_nodes[3])
		table.insert(b_nodes[2].connections, b_nodes[4])
		table.insert(b_nodes[3].connections, b_nodes[5])
		table.insert(b_nodes[4].connections, b_nodes[5])
		table.insert(b_nodes[5].connections, b_nodes[1]) -- Circular dependency

        return a_nodes[1], b_nodes[1]
        ]]
		assert(equal(a, b))
	end)

	test("Mixed self and cross-references", function()
		local a, b = S[[

		-- First structure
		local a1 = {name = "node1"}
		local a2 = {name = "node2"}
		-- Self-references
		a1.self = a1
		a2.self = a2
		-- Cross-references
		a1.other = a2
		a2.other = a1
		-- Nested references
		a1.nested = {parent = a1, sibling = a2}
		a2.nested = {parent = a2, sibling = a1}
		-- Second structure
		local b1 = {name = "node1"}
		local b2 = {name = "node2"}
		-- Self-references
		b1.self = b1
		b2.self = b2
		-- Cross-references
		b1.other = b2
		b2.other = b1
		-- Nested references
		b1.nested = {parent = b1, sibling = b2}
		b2.nested = {parent = b2, sibling = b1}

            return a1, b1
        ]]
		assert(equal(a, b))
	end)

	test("tuple equal", function()
		local tup = ST[[
			local type a = (1,2,3)
			local type b = (1,2,3)
			return a, b
		]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal nested", function()
		local tup = ST[[
			local type a = (1,2,(3, 4, 5))
			local type b = (1,2,(3, 4, 5))
			return a, b
		]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal nested", function()
		local tup = ST[[
			local type a = (1,2,3)
			local type b = (1,2,3)
			type a[4] = a
			type b[4] = b

			return a, b
		]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("union equal", function()
		local tup = ST[[
			local type a = 1|2|3
			local type b = 1|2|3
			return a, b
		]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	-- Edge cases for unions
	test("union equal with different ordering", function()
		local tup = ST[[
        local type a = 1|2|3
        local type b = 3|2|1
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("union equal with nested unions", function()
		local tup = ST[[
        local type a = (1|2)|(3|4)
        local type b = (1|2)|(3|4)
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("union equal one-element union vs non-union", function()
		local tup = ST[[
        local type a = Union<|1|> -- support 1| ?
        local type b = 1
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("union equal with table elements", function()
		local tup = ST[[
        local type a = 1|2|{x = 1, y = 2}
        local type b = 1|2|{x = 1, y = 2}
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("union equal with mixed types", function()
		local tup = ST[[
        local type a = 1|"string"|true
        local type b = 1|"string"|true
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("union equal with different lengths should not be equal", function()
		local tup = ST[[
        local type a = 1|2|3
        local type b = 1|2
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		local equal, reason = equal(a, b)
		assert(not equal, reason)
	end)

	-- Edge cases for tuples
	test("tuple equal empty", function()
		local tup = ST[[
        local type a = ()
        local type b = ()
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal with different ordering", function()
		local tup = ST[[
        local type a = (1,2,3)
        local type b = (3,2,1)
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		local equal, reason = equal(a, b)
		assert(not equal, reason)
	end)

	test("tuple equal deeply nested", function()
		local tup = ST[[
        local type a = (1, (2, (3, 4), 5), 6)
        local type b = (1, (2, (3, 4), 5), 6)
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal with circular reference to parent", function()
		local tup = ST[[
        local type a = (1, 2, 3, nil)
        local type b = (1, 2, 3, nil)
        type a[4] = a
        type b[4] = b
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal with table elements", function()
		local tup = ST[[
        local type a = (1, 2, {x = 1, y = 2})
        local type b = (1, 2, {x = 1, y = 2})
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal with union elements", function()
		local tup = ST[[
        local type a = (1, 2|3, 4)
        local type b = (1, 2|3, 4)
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal with mixed types", function()
		local tup = ST[[
        local type a = (1, "string", true)
        local type b = (1, "string", true)
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("tuple equal with different lengths should not be equal", function()
		local tup = ST[[
        local type a = (1, 2, 3)
        local type b = (1, 2)
        return a, b
    ]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		local equal, reason = equal(a, b)
		assert(not equal, reason)
	end)

	test("fail case", function()
		local a, b = S[[return _ as function=(number)>(nil), _ as function=(number)>(nil)]]
		assert(equal(a, b))
	end)

	test("fail case1", function()
		local tup = ST[[
			local x = {lol = math.random()}

			if x.lol > 0.5 then
				x.foo = "no!"

				do
					x.bar = "true"
					x.tbl = {}

					if math.random() > 0.5 then
						x.tbl.bar = true

						if math.random() > 0.5 then
							x.tbl.foo = {}

							if math.random() > 0.5 then
								x.tbl.foo.test = 1337
								x.tbl.foo.test2 = x
							end
						end
					end
				end
			end

			local analyzer function GetMutatedFromScope(x: Table)
				return x:GetMutatedFromScope(analyzer:GetScope())
			end

			return GetMutatedFromScope<|x|>, _ as ({
				["tbl"] = nil | {
						["foo"] = nil | {
								["test2"] = CurrentType<|"table"|> | nil,
								["test"] = 1337 | nil
						},
						["bar"] = nil | true
				},
				["foo"] = "no!" | nil,
				["lol"] = number,
				["bar"] = "true" | nil
		})
		]]
		local a = tup:GetWithoutExpansion(1)
		local b = tup:GetWithoutExpansion(2)
		assert(equal(a, b))
	end)

	test("fail case 2", function()
		local a, b = S[[
		    local ffi = require("ffi")
			local val: any

			if type(val) == "boolean" then
				val = ffi.new("int[1]", val and 1 or 0)
			elseif type(val) == "number" then
				val = ffi.new("int[1]", val)
			elseif type(val) ~= "cdata" then
				error("uh oh")
			end

			return val, _ as any | ffi.get_type("int[1]")
		]]
		assert(equal(a, b))
	end)
end