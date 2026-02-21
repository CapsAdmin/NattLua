do return end
analyze[[
    -- 1. Defining the Union and types.
    local type TAnyObject = deferred -- Use the reserved "deferred" for forward declaration
    
    local type TObjectA = { Type = "A", Value = number, Next = TAnyObject | nil }
    local type TObjectB = { Type = "B", Flag = boolean, Parent = TObjectA | nil }
    local type TObjectC = { Type = "C", Children = { [number] = TAnyObject } }
    
    -- Patches the reference. All structures above now refer to this full union.
    type TAnyObject = TObjectA | TObjectB | TObjectC

    -- Verify the reference resolves correctly
    attest.subset_of<| TObjectA, { Type = "A", Value = number, Next = TAnyObject | nil } |>
    attest.subset_of<| TAnyObject, TObjectA | TObjectB | TObjectC |>

    -- 2. Narrowing Verification function
    local function process(obj: TAnyObject)
        if obj.Type == "A" then
            attest.subset_of<| obj, TObjectA |>
        elseif obj.Type == "B" then
            attest.subset_of<| obj, TObjectB |>
        elseif obj.Type == "C" then
            attest.subset_of<| obj, TObjectC |>
        end
    end

    -- 3. Usage with recursive links
    local obj_a: TObjectA = { 
        Type = "A", 
        Value = 1, 
        Next = nil 
    }
    local obj_b: TObjectB = { 
        Type = "B", 
        Flag = true, 
        Parent = obj_a 
    }
    obj_a.Next = obj_b

    local obj_c: TObjectC = { 
        Type = "C", 
        Children = { [1] = obj_a, [2] = obj_b } 
    }

    -- 4. Run verification
    process(obj_a)
    process(obj_b)
    process(obj_c)
]]
analyze[==[
    local class = require("nattlua.other.class")

    -- 1. Create templates
    local A_META = class.CreateTemplate("A")
    local B_META = class.CreateTemplate("B")
    local C_META = class.CreateTemplate("C")

    -- 2. Define the union of all our 'type' objects
    --[[# type TAnyObject = A_META.@Self | B_META.@Self | C_META.@Self ]]

    -- 3. Define unique fields
    A_META:GetSet("Value", 0)
    B_META:GetSet("Flag", false)
    C_META:GetSet("Children", {}--[[# as List<|TAnyObject|>]])

    -- 4. Verification function with narrowing
    local function dispatch(obj--[[#: TAnyObject]])
        if obj.Type == "A" then
            -- This should narrow to A_META.@Self
            attest.equal(obj.Value, _ as number)
        elseif obj.Type == "B" then
            -- This should narrow to B_META.@Self
            attest.equal(obj.Flag, _ as boolean)
        elseif obj.Type == "C" then
            -- This should narrow to C_META.@Self
            attest.equal(obj.Children, _ as List<|TAnyObject|>)
        end
    end

    -- 5. Test instances
    local a = A_META.NewObject({Value = 1337})
    local b = B_META.NewObject({Flag = true})
    local c = C_META.NewObject({Children = {a, b}})

    dispatch(a)
    dispatch(b)
    dispatch(c)

]==]
