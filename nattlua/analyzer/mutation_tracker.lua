local types = require("nattlua.types.types")

local META = {}
META.__index = META

function META:GetValueFromScope(scope, upvalue, key)
    local mutations = {}
    
    do
        for from, mutation in ipairs(self.mutations) do
            do 
                --[[
                Remove redundant mutations that happen in the same same scope. 
                The last mutation is the one that matters.

                local a = 1 --<< from here
                
                if true then
                    a = 6
                    do a = 100 end
                    a = 2
                end

                a = 2 --<< to here

            ]]
                for i = #mutations, 1, -1 do
                    if mutations[i].scope == mutation.scope then
                        for i = from, i, -1 do 
                            table.remove(mutations, i)    
                        end
                        break
                    end
                end
            end

            -- if we're inside an if statement, we know for sure that the other parts of that if statements have not been hit
            if scope.if_statement and mutation.scope.if_statement == scope.if_statement and scope ~= mutation.scope then
            else 
                table.insert(mutations, mutation)                            
            end
        end

        do --[[
            if mutations occured in an if statement that has an else part, remove all mutations before the if statement

        ]] 
            for i = #mutations, 1, -1 do
                local change = mutations[i]

                if change.scope.if_statement and change.scope.test_condition_inverted then
                    
                    local statement = change.scope.if_statement
                    while true do
                        local change = mutations[i]
                        if not change then break end
                        if change.scope.if_statement ~= statement then
                            for i = i, 1, -1 do
                                table.remove(mutations, i)
                            end
                            break
                        end                                       
                    
                        i = i - 1
                    end

                    break
                end
            end
        end
        
        -- if the same reference type is used in a condition, all conditions must be either true or false at the same time
        for _, a in ipairs(mutations) do
            for _, b in ipairs(mutations) do
                if a.scope.test_condition and b.scope.test_condition then
                    if types.FindInType(a.scope.test_condition, b.scope.test_condition) then
                        a.linked_mutations = a.linked_mutations or {}
                        table.insert(a.linked_mutations, b)
                    end
                end
            end
        end

        if scope.test_condition then -- make scopes that use the same type condition certrain
            for _, change in ipairs(mutations) do
                if change.scope ~= scope and change.scope.test_condition and types.FindInType(change.scope.test_condition, scope.test_condition) then
                    change.certain_override = true
                end
            end
        end
    end
    
    local union = types.Union({})
    union.upvalue = upvalue
    union.upvalue_keyref = key
    
    for _, change in ipairs(mutations) do

        do
            --[[
                local x: nil | true
                if not x then
                    x = true
                end

                -- x is true here
            ]]
            local scope, scope_union = change.scope:FindScopeFromTestCondition(change.value)
            if scope and change.scope == scope and scope.test_condition.Type == "union" then
                local t
                if scope.test_condition_inverted then
                    t = scope_union.falsy_union or scope.test_condition:GetFalsy()
                else
                    t = scope_union.truthy_union or scope.test_condition:GetTruthy()
                end

                if t then
                    union:RemoveType(t)
                end
            end
        end
    
        if change.certain_override or change.scope:IsCertain(scope) then
            union:Clear()
        end

        if _ == 1 and change.value.Type == "union" then
            if upvalue.Type == "table" then
                union = change.value:Copy()
                union.upvalue = upvalue
                union.upvalue_keyref = key
            else 
                union = change.value:Copy()
                union.upvalue = upvalue
                union.upvalue_keyref = key
            end
        else
            union:AddType(change.value)
        end
    end

    local value = union
    
    if #union:GetData() == 1 then
        value = union:GetData()[1]
    end

    if value.Type == "union" then
        --[[

            this is only for when unions have been tested for

            local x = true | false

            if 
                x -- x is split into a falsy and truthy union in the binary operator
            then
                print(x) -- x is true here
            end
        ]]

        local scope, union = scope:FindScopeFromTestCondition(value)

        if scope then 
            local current_scope = scope

            if #self.mutations > 1 then
                for i = #self.mutations, 1, -1 do
                    if self.mutations[i].scope == current_scope then
                        return value
                    else
                        break
                    end
                end
            end
        

            local t

            -- the or part here refers to if *condition* then
            -- truthy/falsy _union is only created from binary operators and some others
            if scope.test_condition_inverted then
                t = union.falsy_union or value:GetFalsy()
            else
                t = union.truthy_union or value:GetTruthy()
            end
                        
            return t
        end
    end

    return value
end

function META:HasMutations()
    return self.mutations[1] ~= nil
end

function META:Mutate(value, scope)
    table.insert(self.mutations, {
        scope = scope,
        value = value,
    })
    return self
end

return function()
    return setmetatable({mutations = {}}, META)
end 