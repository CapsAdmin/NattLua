--[[
    this has probably been the most difficult part about the analyzer
    the code here is not very elegant and i strongly favor readable code over optimizations

    i hope that there's a much simpler way of doing this that will become apparent sometime
]]

local types = require("nattlua.types.types")
local tprint = require("nattlua.other.tprint")

local META = {}
META.__index = META

local DEBUG = false 

local function dprint(mut, reason)
    if not DEBUG then return end

    print("\t" .. tostring(mut.scope) .. " - " .. tostring(mut.value) .. ": " .. reason)
end

local function same_if_statement(a, b)
    return a.if_statement and a.if_statement == b.if_statement
end

function META:GetValueFromScope(scope, upvalue, key, analyzer)
    local mutations = {}

    if DEBUG then print("looking up mutations for " .. tostring(upvalue) .. "." .. tostring(key) .. ":") end

    do
        
        for _, mut in ipairs(self.mutations) do
            --[[
                if we're inside an if statement, we know for sure that the other parts of that if statements have not been hit

                local x = 1

                if maybe then
                    x = 2 << discard
                elseif maybe then
                    x = 3 << discard
                else
            >>      x = 4
                end
            ]]
            if same_if_statement(scope, mut.scope) and scope ~= mut.scope then
                if DEBUG then dprint(mut, "not inside the same if statement") end
            else 
                if DEBUG then dprint(mut, "adding") end
                table.insert(mutations, mut)                            
            end
        end

    do

        --[[
                if we're inside an if statement, we know for sure that the other parts of that if statements have not been hit

                local x = 1

                x = 1 << repeated mutation is redudant
                ...
                x = 2
            
            >>  x == 2
            ]]

        local last_scope
        for i = #mutations, 1, -1 do
            local mut = mutations[i]

            if last_scope and mut.scope == last_scope then
                if DEBUG then dprint(mut, "redudant mutation") end
                table.remove(mutations, i)
            end

            last_scope = mut.scope
        end
    end

        do --[[
            if mutations occured in an if statement that has an else part, remove all mutations before the entire if statement
            but only if we are a sibling of the if statement's scope

            local x = 1 << discard
             
            if maybe then
                x = 2
            else
                x = 3
            end

        >>  x == 2 | 3
        ]] 
            for i = #mutations, 1, -1 do
                local mut = mutations[i]

                if mut.scope.if_statement and mut.scope.test_condition_inverted then
                    
                    local if_statement = mut.scope.if_statement
                    while true do
                        local mut = mutations[i]
                        if not mut then break end
                        if mut.scope.if_statement ~= if_statement then
                            for i = i, 1, -1 do
                                if mutations[i].scope:Contains(scope) then
                                    if DEBUG then dprint(mut, "redudant mutation before else part of if statement") end
                                    table.remove(mutations, i)
                                end
                            end
                            break
                        end                                       
                    
                        i = i - 1
                    end

                    break
                end
            end
        end

        do
            --[[
                make scopes that use the same test condition certrain

                local x = 1
                local test = maybe

                if test then  << this becomes certain from the other scopes point of view
                    x = 2
                end

                if test then
            >>      x == 2    
                end
            ]]

            local test_a = scope:GetTestCondition()
            
            if test_a then
                for _, mut in ipairs(mutations) do
                    if mut.scope ~= scope then 
                        local test_b = mut.scope:GetTestCondition()

                        if test_b then
                            if types.FindInType(test_a, test_b) then
                                mut.certain_override = true
                                if DEBUG then dprint(mut, "forcing scope certainty because this scope is using the same test condition") end
                            end
                        end
                    end
                end
            end
        end
    end
    
    local union = types.Union({})
    union.upvalue = upvalue
    union.upvalue_keyref = key
    
    for _, mut in ipairs(mutations) do
        local obj = mut.value

        do
            --[[
                local x: nil | true

                if not x then
                    x = true
                end

            >>  x == true
            ]]
            local scope, scope_union = mut.scope:FindScopeFromTestCondition(obj)
            if scope and mut.scope == scope and scope.test_condition.Type == "union" then
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
    
        if mut.certain_override or mut.scope:IsCertain(scope) then
            union:Clear()
        end

        if _ == 1 and obj.Type == "union" then
            if upvalue.Type == "table" then
                union = obj:Copy()
                union.upvalue = upvalue
                union.upvalue_keyref = key
            else 
                union = obj:Copy()
                union.upvalue = upvalue
                union.upvalue_keyref = key
            end
        else
            if obj.Type == "function" and not obj.called and not obj.explicit_return and union:HasType("function") then
                analyzer:Assert(obj:GetNode() or analyzer.current_expression, analyzer:Call(obj, obj:GetArguments():Copy()))
            end

            union:AddType(obj)
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

            if x then
        >>      x == true
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