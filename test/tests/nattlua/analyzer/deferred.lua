do
	return
end

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
