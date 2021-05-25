local T = require("test.helpers")
local run = T.RunCode
local types = require("nattlua.types.types")

test("a and b", function()
    local obj = run[[
        local a: 1, b: 2
        local result = a and b

        type_assert(result, 2)
    ]]:GetLocalOrEnvironmentValue(types.LString("result"), "runtime")

    equal(obj:GetNode().kind, "binary_operator") 
    equal(obj:GetTypeSource():GetData(), 2)
    equal(obj:GetTypeSourceLeft():GetData(), 1)
    equal(obj:GetTypeSourceRight():GetData(), 2)
    equal(obj:GetTypeSourceRight(), obj:GetTypeSource())
end)

test("a + b", function()
    local obj = run[[
        local a: 1, b: 2
        local result = a + b
        
        type_assert(result, 3)
    ]]:GetLocalOrEnvironmentValue(types.LString("result"), "runtime")

    equal(obj:GetNode().kind, "binary_operator")
    equal(obj:GetData(), 3)
    equal(obj:GetTypeSourceLeft():GetData(), 1)
    equal(obj:GetTypeSourceRight():GetData(), 2)
end)

test("not a", function()
    local obj = run[[
        local a: true
        local result = not a
        
        type_assert(result, false)
    ]]:GetLocalOrEnvironmentValue(types.LString("result"), "runtime")

    equal(obj:GetNode().kind, "prefix_operator") 
    equal(obj:GetTypeSource():GetData(), true)
end)

test("not not a", function()
    local obj = run[[
        local a: true
        local result = not not a
        
        type_assert(result, true)
    ]]:GetLocalOrEnvironmentValue(types.LString("result"), "runtime")

    equal(obj:GetNode().kind, "prefix_operator") 
    equal(obj:GetTypeSource():GetData(), false)
    equal(obj:GetTypeSource():GetTypeSource():GetData(), true)
end)

test("not a or 1", function()
    local obj = run[[
        local a = true
        local result = not a or 1
        
        type_assert(result, 1)
    ]]:GetLocalOrEnvironmentValue(types.LString("result"), "runtime")

    equal(obj:GetNode().kind, "binary_operator")
    equal(obj:GetTypeSourceLeft():GetNode().kind, "prefix_operator")
    equal(obj:GetTypeSourceLeft():GetData(), false)
    equal(obj:GetTypeSource():GetData(), 1)
end)


test("1 or 2 or 3 or 4", function()
    -- each value here has to be 1 | nil, otherwise it won't traverse the or chain
    local obj = run[[local result = (_ as 1 | nil) or (_ as 2 | nil) or (_ as 3 | nil) or (_ as 4 | nil)]]:GetLocalOrEnvironmentValue(types.LString("result"), "runtime")
    local function set_equal(a, b)
        if not a then error("a is nil", 2) end
        
        local literal_union = {types.Symbol(nil)}
        for _, num in ipairs(b) do
            table.insert(literal_union, types.LNumber(num))
        end
        assert(a:Equal(types.Union(literal_union)))
    end
    -- (>1< or 2 or 3) or (>4<)
    set_equal(obj:GetTypeSourceLeft(), {1,2,3})
    set_equal(obj:GetTypeSourceRight(), {4})

    local obj = obj:GetTypeSourceLeft()
    -- (>1< or 2) or (>3<)
    set_equal(obj:GetTypeSourceLeft(), {1,2})
    set_equal(obj:GetTypeSourceRight(), {3})

    local obj = obj:GetTypeSourceLeft()
    -- (>1<) or (>2<)
    set_equal(obj:GetTypeSourceLeft(), {1})
    set_equal(obj:GetTypeSourceRight(), {2})
end)


pending[[
    local a: false | 1

    local x = not a
    § assert(env.runtime.x:Equal(types.Boolean()))
    § assert(env.runtime.x.source:Equal("number-1|symbol-false"))
    § assert(env.runtime.x.falsy_union:Equal("number-1"))
    § assert(env.runtime.x.truthy_union:Equal("symbol-false"))

]]