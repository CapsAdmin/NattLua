local types = require("nattlua.types.types")

return function(META) 
    function META:NewIndexOperator(node, obj, key, val, env)
        if obj.Type == "union" then
            -- local x: nil | {foo = true}
            -- log(x.foo) << error because nil cannot be indexed, to continue we have to remove nil from the union
            -- log(x.foo) << no error, because now x does not contain nil
            
            local new_union = types.Union()
            local truthy_union = types.Union()
            local falsy_union = types.Union()
    
            for _, v in ipairs(obj:GetTypes()) do
                local ok, err = self:NewIndexOperator(node, v, key, val, env)
    
                if not ok then
                    self:ErrorAndCloneCurrentScope(node, err or "invalid set error", obj)
                    falsy_union:AddType(v)
                else
                    truthy_union:AddType(v)
                    new_union:AddType(v)
                end
            end
    
            truthy_union.upvalue = obj.upvalue
            falsy_union.upvalue = obj.upvalue
            new_union.truthy_union = truthy_union
            new_union.falsy_union = falsy_union
    
            return new_union:SetSource(node, new_union, obj)
        end
    
        if obj.meta then
            local func = obj.meta:Get("__newindex")
    
            if func then
                if func.Type == "table" then
                    return func:Set(key, val)
                end
    
                if func.Type == "function" then
                    return self:Call(func, types.Tuple({obj, key, val}), key.node)
                end
            end
        end
    
        if not self:MutateValue(obj, key, val, env) then -- always false?
            return obj:Set(key, val)
        end
    end
end