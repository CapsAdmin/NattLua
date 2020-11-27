local types = require("nattlua.types.types")

return function(META) 
    function META:IndexOperator(obj, key, node)
        if obj.Type == "union" then
            local copy = types.Union()
            for _,v in ipairs(obj:GetTypes()) do
                local val, err = self:IndexOperator(v, key, node)
                if not val then
                    return val, err
                end
                copy:AddType(val)
            end
            return copy
        end
    
        if obj.Type ~= "table" and obj.Type ~= "tuple" and obj.Type ~= "list" and (obj.Type ~= "string") then
            return obj:Get(key)
        end
        
        if obj.meta and (obj.Type ~= "table" or not obj:Contains(key)) then
            local index = obj.meta:Get("__index")
    
            if index then
                if index.Type == "table" then
                    return self:IndexOperator(index.contract or index, key, node)
                end
    
                if index.Type == "function" then
                    local obj, err = self:Call(index, types.Tuple({obj, key}), key.node)
                    
                    if not obj then
                        return obj, err
                    end
    
                    return obj:Get(1)
                end
            end
        end
        
        if obj.contract then
            return obj:Get(key)
        end
    
        -- local obj: {string = number}
        -- obj.foo = 1
        -- log(obj.foo) << since the contract states that key is a string, then obj.foo would be nil or a number
        -- this adds some additional context
        if obj.last_set and not key:IsLiteral() and obj.last_set[key] then
            return obj.last_set[key]
        end
    
        local val, err = obj:Get(key)
    
        if not val then
            return self:NewType(node or obj.node, "nil"):AddReasonForExistance("failed to get " .. tostring(key) .. " from table because " .. err)
        end
    
        return val
    end
end