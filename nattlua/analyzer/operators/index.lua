local types = require("nattlua.types.types")

return function(META) 
    function META:IndexOperator(node, obj, key, env)
        if obj.Type == "union" then
            local copy = types.Union()
            for _,v in ipairs(obj:GetTypes()) do

                local val, err = self:IndexOperator(node, v, key, env)
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
        
        if obj:GetMetaTable() and (obj.Type ~= "table" or not obj:Contains(key)) then
            local index = obj:GetMetaTable():Get("__index")
    
            if index then
                if index.Type == "table" then
                    return self:IndexOperator(node, index:GetContract() or index, key, env)
                end
    
                if index.Type == "function" then
                    local obj, err = self:Call(index, types.Tuple({obj, key}), key:GetNode())
                    
                    if not obj then
                        return obj, err
                    end
    
                    return obj:Get(1)
                end
            end
        end

        -- changes in tables would have to be stored in a change list..

        if obj:GetContract() then
            local val, err = obj:GetContract():Get(key)

            if val then
                local o = self:GetMutatedValue(obj, key, val, env)

                if o then
                    return o
                end

                return val
            end

            return val, err
        end

        local val, err = obj:Get(key)

        if val then
            local o = self:GetMutatedValue(obj, key, val, env)

            if o then
                return o
            end

            return val
        end
    
        if not val then
            self:Warning(node or obj:GetNode(), err)
            return self:NewType(node or obj:GetNode(), "nil")
        end
    
        return val
    end
end