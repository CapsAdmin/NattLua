
local table_insert = table.insert
local META = {}
META.__index = META

local LexicalScope

function META:Initialize()
    
end

function META:SetParent(parent)
    self.parent = parent
    if parent then
        parent:AddChild(self)
    end
end

function META:AddChild(scope)
    scope.parent = self
    table_insert(self.children, scope)
end

function META:Unparent()
    if self.parent then
        for i,v in ipairs(self.parent:GetChildren()) do
            if v == self then
                table.remove(i, self.parent:GetChildren())
                break
            end
        end
    end
    self.parent = nil
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

function META:MakeReadOnly(b)
    self.read_only = b
end

function META:GetParents()
    local list = {}

    local scope = self

    while true do
        table.insert(list, scope)
        scope = scope.parent
        if not scope then
            break
        end
    end

    return list
end

function META:GetMemberInParents(what)
    for _, scope in ipairs(self:GetParents()) do
        if scope[what] then
            return scope[what], scope
        end
    end

    return nil
end

function META:IsReadOnly()
    return self:GetMemberInParents("read_only")
end

function META:GetIterationScope()
    local boolean, scope = self:GetMemberInParents("is_iteration_scope")
    return scope
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

local upvalue_meta

do
    local META = {}
    META.__index = META

    function META:__tostring()
        return "[" .. self.key .. ":" .. tostring(self.data) .. "]"
    end

    function META:GetValue()
        return self.data
    end

    function META:SetValue(data)
        self.data = data
    end

    upvalue_meta = META
end

function META:CreateValue(key, obj, env)
    local key_hash = self:Hash(key)

    local upvalue = {
        data = obj,
        key = key_hash,
        shadow = self:FindValue(key, env),
        mutations = {
            {
                scope = self,
                value = obj,
            }
        }
    }

    setmetatable(upvalue, upvalue_meta)

    table_insert(self.upvalues[env].list, upvalue)
    self.upvalues[env].map[key_hash] = upvalue

    return upvalue
end

function META:Copy(upvalues)
    local copy = LexicalScope()

    if upvalues then
        for env, data in pairs(self.upvalues) do
            for _, obj in ipairs(data.list) do
                copy:CreateValue(obj.key, obj.data, env)
            end
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

function META:HasParent(scope)
    for _, parent in ipairs(self:GetParents()) do
        if parent == scope then
            return true 
        end
    end

    return false
end

function META:SetTestCondition(obj, inverted)
    self.test_condition = obj
    self.test_condition_inverted = inverted
end

function META:GetTestCondition()
    local obj, scope = self:GetMemberInParents("test_condition")
    return obj, scope and scope.test_condition
end

local types = require("nattlua.types.types")

function META:FindScopeFromTestCondition(obj)
    local scope = self
    while true do
        if types.FindInType(scope.test_condition, obj) then
            break
        end
        
        -- find in siblings too, if they have returned
        -- ideally when cloning a scope, the new scope should be 
        -- inside of the returned scope, then we wouldn't need this code
        
        for _, child in ipairs(scope.children) do
            if child ~= scope and child.uncertain_returned then
                if types.FindInType(child.test_condition, obj) then
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
        local ok, scope = self:GetMemberInParents("returns")
        if ok then
            return scope
        end

        error("cannot find a scope to return to", 2)
    end

    function META:GetReturnTypes()
        return self.returns
    end

    function META:ClearReturnTypes()
        self.returns = {}
    end

    function META:IsCertain(from)
        return not self:IsUncertain(from)
    end

    function META:IsUncertain(from)
        if from == self then return false end
        for _, scope in ipairs(self:GetParents()) do
            if scope == from then break end
            if scope.uncertain then
                return true, scope
            end
        end

        return false
    end

    function META:MakeUncertain(b)
        self.uncertain = b
    end
end

local ref = 0

function META:__tostring()
    local x = #self:GetParents()
    local y = 1
    if self.parent then
        for i, v in ipairs(self.parent:GetChildren()) do
            if v == self then
                y = i
                break
            end
        end
    end

    local s = "scope["..x..","..y.."]" .. "[".. (self:IsUncertain() and "uncertain" or "certain") .."]" .. "[" .. tostring(self:GetTestCondition() or nil) .. "]"
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

function LexicalScope(parent)    
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
    }

    setmetatable(scope, META)

    scope:SetParent(parent)

    return scope
end

return LexicalScope