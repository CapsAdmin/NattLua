local types = require("nattlua.types.types")

return function(META) 
    function META:NewIndexOperator(node, obj, key, val, env)
        if obj.Type == "union" then
            -- local x: nil | {foo = true}
            -- log(x.foo) << error because nil cannot be indexed, to continue we have to remove nil from the union
            -- log(x.foo) << no error, because now x has no field nil
            
            local new_union = types.Union()
            local truthy_union = types.Union()
            local falsy_union = types.Union()
    
            for _, v in ipairs(obj:GetData()) do
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
    
            return new_union:SetNode(node):SetSource(new_union):SetBinarySource(obj)
        end

        if val.Type == "function" and val:GetNode().self_call then
            local arg = val:GetArguments():Get(1)
            if not arg:GetContract() then
                val.called = true
                val = val:Copy()
                val:GetArguments():Set(1, types.Union({types.Any(), obj}))
                self:CallMeLater(val, val:GetArguments(), val:GetNode(), true)
            end
        end

        self:FireEvent("newindex", obj, key, val, env)
    
        if obj:GetMetaTable() then
            local func = obj:GetMetaTable():Get("__newindex")
    
            if func then
                if func.Type == "table" then
                    return func:Set(key, val)
                end
    
                if func.Type == "function" then
                    return self:Assert(node, self:Call(func, types.Tuple({obj, key, val}), key:GetNode()))
                end
            end
        end

        if not self:MutateValue(obj, key, val, env) then -- always false?
            return obj:Set(key, val)
        end
    end
end