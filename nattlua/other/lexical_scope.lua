
local table_insert = table.insert
local META = {}
META.__index = META

local LexicalScope

function META:Initialize(node, extra_node, event_data)
    
end

function META:SetParent(parent)
    self.parent = parent
    parent:AddChild(self)
end

function META:AddChild(scope)
    table_insert(self.children, scope)
end

function META:GetChildren()
    return self.children
end

function META:Hash(node)
    if type(node) == "string" then
        return node
    end

    if type(node.value) == "string" then
        return node.value
    end

    return node.value.value
end

function META:FindValue(key, env)
    local key_hash = self:Hash(key)

    local scope = self
    local current_scope = scope
    
    while scope do
        if scope.upvalues[env].map[key_hash] then
            return scope.upvalues[env].map[key_hash], current_scope
        end
        current_scope = scope
        scope = scope.parent
    end
end

function META:CreateValue(key, obj, env)
    local key_hash = self:Hash(key)

    local upvalue = {
        data = obj,
        key = key_hash,
        shadow = self:FindValue(key, env),
    }

    table_insert(self.upvalues[env].list, upvalue)
    self.upvalues[env].map[key_hash] = upvalue

    return upvalue
end

function META:Copy(node)
    local copy = LexicalScope(node or self.node, self.extra_node, self.event_data)

    for env, data in pairs(self.upvalues) do
        for _, obj in ipairs(data.list) do
            copy:CreateValue(obj.key, obj.data, env)
        end
    end
    
    copy.returns = self.returns

    return copy
end

function META:Merge(scope)
    local types = require("nattlua.types.types")
    for i, a in ipairs(self.upvalues.runtime.list) do
        local b = scope.upvalues.runtime.list[i]
        if a and b and a.key == b.key then
            a.data = types.Union({a.data, b.data})
            a.data.node = b.data.node
            a.data.node_label = b.data.node_label
            self.upvalues.runtime.map[a.key].data = a.data
        end
    end
end

function META:GetTestCondition()
    local scope = self
    while true do
        if scope.test_condition then
            break
        end
        scope = scope.parent
        if not scope then
            return
        end
    end
    return scope.test_condition, scope.test_condition_inverted
end

local function compare_condition(scope, obj)
    local condition = scope.test_condition
    if 
        condition and (
            -- this is not correct for complex conditions like 
            -- if not not not false and true or not true then
            condition == obj or 
            condition.source == obj or 
            condition.source_left == obj or 
            condition.source_right == obj or
            condition.type_checked == obj
        )
    then
        return true
    end

    return false
end

function META:FindScopeFromTestCondition(obj)
    local scope = self
    while true do
        if compare_condition(scope, obj) then
            break
        end
        
        -- find in siblings too, if they have returned
        -- ideally when cloning a scope, the new scope should be 
        -- inside of the returned scope, then we wouldn't need this code
        
        for _, child in ipairs(scope.children) do
            if child ~= scope and child.uncertain_returned then
                if compare_condition(child, obj) then
                    return child
                end
            end
        end

        scope = scope.parent            
        
        if not scope then
            return
        end
    end

    return scope
end

do
    function META:MakeFunctionScope()
        self.returns = {}
    end

    function META:CollectReturnTypes(types)
        table.insert(self:GetNearestFunctionScope().returns, types)
    end

    function META:DidReturn()
        return self.returned ~= nil
    end

    function META:ClearReturn()
        self.returned = nil
    end

    function META:Return(uncertain)
        local scope = self
        while true do

            if uncertain then
                scope.uncertain_returned = true
                scope.test_condition_inverted = not scope.test_condition_inverted
            else 
                scope.returned = true
            end
            if scope.returns then
                break
            end

            scope = scope.parent

            if not scope then
                break
            end
        end
    end

    function META:GetNearestFunctionScope()
        local scope = self
        while true do
            
            if scope.returns then
                return scope 
            end

            scope = scope.parent

            if not scope then
                break
            end
        end

        error("cannot find a scope to return to", 2)
    end

    function META:GetReturnTypes()
        return self.returns
    end

    function META:ClearReturnTypes()
        self.returns = {}
    end

    function META:IsUncertain()
        return self.uncertain
    end

    function META:MakeUncertain(b)
        self.uncertain = b
    end
end

local ref = 0

function META:__tostring()
    local s = "scope[" .. self.ref .. "]" .. "[".. (self:IsUncertain() and "uncertain" or "certain") .."]" .. "[" .. tostring(self:GetTestCondition() or nil) .. "]"
    if self.returns then
        s = s .. "[function scope]"
    end

    return s
end

function META:DumpScope()
    local s = {}
    for i, v in ipairs(self.upvalues.runtime.list) do
        table.insert(s, "local " .. tostring(v.key) .. " = " .. tostring(v.data))
    end
    for i,v in ipairs(self.children) do
        table.insert(s, "do\n" .. v:DumpScope() .. "\nend\n")
    end
    return table.concat(s, "\n")
end

function LexicalScope(node, extra_node, event_data)
    assert(type(node) == "table" and node.kind, "expected an associated ast node")
    ref = ref + 1

    local scope = {
        ref = ref,
        children = {},

        upvalues = {
            runtime = {
                list = {},
                map = {},
            },
            typesystem = {
                list = {},
                map = {},
            }
        },

        node = node,
        extra_node = extra_node,
        event_data = event_data,
    }

    setmetatable(scope, META)

    return scope
end

return LexicalScope