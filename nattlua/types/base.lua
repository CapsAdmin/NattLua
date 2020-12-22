local types = require("nattlua.types.types")

local META = {}

function META:IsUncertain()
    return self:IsTruthy() and self:IsFalsy()
end

function META:CopyInternalsFrom(obj)
    self.name = obj.name
    self.node = obj.node
    self.node_label = obj.node_label
    self.source = obj.source
    self.source_left = obj.source_left
    self.source_right = obj.source_right
    self.explicit_not_literal = obj.explicit_not_literal

    if obj:GetName() then
        self:SetName(obj:GetName():Copy())
    end
    
    if obj:GetContract() then
        self:SetContract(obj:GetContract())
    end

    -- what about these?
    --self.truthy_union = obj.truthy_union
    --self.falsy_union = obj.falsy_union
    --self.upvalue_keyref = obj.upvalue_keyref
    --self.upvalue = obj.upvalue
end

function META:SetSource(node, source, l,r)
    self.source = source
    self.node = node
    self.source_left = l
    self.source_right = r        
    return self
end 

function META:GetSignature()
    error("NYI")
end

function META:GetSignature()
    error("NYI")
end

function META:SetName(name)
    if name then
        assert(name:IsLiteral())
    end
    self.Name = name
end

function META:GetName()
    return self.Name
end

META.literal = false

function META:MakeExplicitNotLiteral(b)
    self.explicit_not_literal = b
    return self
end


do
    local ref = 0

    function META:MakeUnique(b)
        if b then
            self.unique_id = ref
            ref = ref + 1
        else 
            self.unique_id = nil
        end
        return self
    end

    function META:IsUnique()
        return self.unique_id ~= nil
    end

    function META:GetUniqueID()
        return self.unique_id
    end

    function META:DisableUniqueness()
        self.disabled_unique_id = self.unique_id
        self.unique_id = nil
    end

    function META:EnableUniqueness()
        self.unique_id = self.disabled_unique_id
    end

    function types.IsSameUniqueType(a, b)
        if a.unique_id and not b.unique_id then
            return types.errors.other(tostring(a) .. "is a unique type")
        end

        if b.unique_id and not a.unique_id then
            return types.errors.other(tostring(b) .. "is a unique type")
        end

        if a.unique_id ~= b.unique_id then
            return types.errors.other(tostring(a) .. "is not the same unique type as " .. tostring(a))
        end

        return true
    end
end

function META:MakeLiteral(b)
    self.literal = b
    return self
end

function META:IsLiteral()
    return self.literal
end

function META:Seal()
    self:SetContract(self:GetContract() or self:Copy())
end

function META:CopyLiteralness(obj)
    self:MakeLiteral(obj:IsLiteral())    
end

function META:Call(...)
    return types.errors.other("type " .. self.Type .. ": " .. tostring(self) .. " cannot be called")        
end

function META:SetReferenceId(ref)
    self.reference_id = ref
    return self
end

function META:Set(key, val)
    return types.errors.other("undefined set: " .. tostring(self) .. "[" .. tostring(key) .. "] = " .. tostring(val) .. " on type " .. self.Type)
end

function META:Get(key)
    return types.errors.other("undefined get: " .. tostring(self) .. "[" .. tostring(key) .. "]" .. " on type " .. self.Type)
end

function META:AddReason(reason, ...)
    table.insert(self.reasons, {
        msg = reason,
        data = {...}
    })
    return self
end

function META:GetReasonForExistance()
    local str = ""
    
    for k,v in ipairs(self.reasons) do
        str = str .. v.msg .. "\n"
    end

    return str
end

function META:SetParent(parent)
    if parent then
        if parent ~= self then
            self.parent = parent
        end
    else
        self.parent = nil
    end
end

function META:GetRoot()
    local parent = self
    local done = {}
    while true do
        if not parent.parent or done[parent] then
            break
        end
        done[parent] = true
        parent = parent.parent
    end
    return parent
end

function META:SetMetaTable(tbl)
    self.MetaTable = tbl
end

function META:GetMetaTable()
    return self.MetaTable
end

function META:SetContract(val)
    self.Contract = val
end

function META:GetContract()
    return self.Contract
end

return META