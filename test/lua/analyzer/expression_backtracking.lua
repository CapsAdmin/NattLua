local T = require("test.helpers")
local run = T.RunCode
local types = require("oh.typesystem.types")

test("a and b", function()
    local obj = run[[
        local a: 1, b: 2
        local result = a and b

        type_assert(result, 2)
    ]]:GetEnvironmentValue("result", "runtime")

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
    ]]:GetEnvironmentValue("result", "runtime")

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
    ]]:GetEnvironmentValue("result", "runtime")

    equal(obj.node.kind, "prefix_operator") 
    equal(obj.source.data, true)
end)

test("not not a", function()
    local obj = run[[
        local a: true
        local result = not not a
        
        type_assert(result, true)
    ]]:GetEnvironmentValue("result", "runtime")

    equal(obj.node.kind, "prefix_operator") 
    equal(obj.source.data, false)
    equal(obj.source.source.data, true)
end)

test("not a or 1", function()
    local obj = run[[
        local a = true
        local result = not a or 1
        
        type_assert(result, 1)
    ]]:GetEnvironmentValue("result", "runtime")

    equal(obj.node.kind, "binary_operator")
    equal(obj.source_left.node.kind, "prefix_operator")
    equal(obj.source_left.data, false)
    equal(obj.source.data, 1)
end)


test("1 or 2 or 3 or 4", function()
    -- each value here has to be 1 | nil, otherwise it won't traverse the or chain
    local obj = run[[local result = (_ as 1 | nil) or (_ as 2 | nil) or (_ as 3 | nil) or (_ as 4 | nil)]]:GetEnvironmentValue("result", "runtime")
    local function set_equal(a, b)
        local literal_set = {types.Symbol(nil)}
        for _, num in ipairs(b) do
            table.insert(literal_set, types.Number(num):MakeLiteral(true))
        end
        equal(a:GetSignature(), types.Set(literal_set):GetSignature())
        types.Set({types.Number(1):MakeLiteral(true),types.Number(2):MakeLiteral(true),types.Number(3):MakeLiteral(true),types.Symbol(nil)}):GetSignature()
    end
    -- (>1< or 2 or 3) or (>4<)
    set_equal(obj.source_left, {1,2,3})
    set_equal(obj.source_right, {4})

    local obj = obj.source_left
    -- (>1< or 2) or (>3<)
    set_equal(obj.source_left, {1,2})
    set_equal(obj.source_right, {3})

    local obj = obj.source_left
    -- (>1<) or (>2<)
    set_equal(obj.source_left, {1})
    set_equal(obj.source_right, {2})
end)
