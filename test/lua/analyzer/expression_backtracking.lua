local T = require("test.helpers")
local run = T.RunCode

test("a and b", function()
    local obj = run[[
        local a: 1, b: 2
        local result = a and b

        type_assert(result, 2)
    ]]:GetValue("result", "runtime")

    equal(obj.node.kind, "binary_operator") 
    equal(obj.source.data, 2)
    equal(obj.source_left.data, 1)
    equal(obj.source_right.data, 2)
    equal(obj.source_right, obj.source)
end)

test("a + b", function()
    local obj = run[[
        local a: 1, b: 2
        local result = a + b
        
        type_assert(result, 3)
    ]]:GetValue("result", "runtime")

    equal(obj.node.kind, "binary_operator")
    equal(obj.source.data, 3)
    equal(obj.source_left.data, 1)
    equal(obj.source_right.data, 2)
end)

test("not a", function()
    local obj = run[[
        local a: true
        local result = not a
        
        type_assert(result, false)
    ]]:GetValue("result", "runtime")

    equal(obj.node.kind, "prefix_operator") 
    equal(obj.source.data, true)
end)

test("not not a", function()
    local obj = run[[
        local a: true
        local result = not not a
        
        type_assert(result, true)
    ]]:GetValue("result", "runtime")

    equal(obj.node.kind, "prefix_operator") 
    equal(obj.source.data, false)
    equal(obj.source.source.data, true)
end)

test("not a or 1", function()
    local obj = run[[
        local a = true
        local result = not a or 1
        
        type_assert(result, 1)
    ]]:GetValue("result", "runtime")

    equal(obj.node.kind, "binary_operator")
    equal(obj.source_left.node.kind, "prefix_operator")
    equal(obj.source_left.data, false)
    equal(obj.source.data, 1)
end)

test("1 or 2 or 3 or 4", function()
    local obj = run[[local result = 1 or 2 or 3 or 4]]:GetValue("result", "runtime")
    -- (>1< or 2 or 3) or (>4<)
    equal(obj.source_left.data, 1)
    equal(obj.source_right.data, 4)

    local obj = obj.source_left
    -- (>1< or 2) or (>3<)
    equal(obj.source_left.data, 1)
    equal(obj.source_right.data, 3)

    local obj = obj.source_left
    -- (>1<) or (>2<)
    equal(obj.source_left.data, 1)
    equal(obj.source_right.data, 2)
end)
