local util = require("oh.util")
local oh = require("oh.oh")
local code = io.open("examples/scope_walking.lua"):read("*all")

local tk = oh.Tokenizer(code)
local ps = oh.Parser()
local em = oh.LuaEmitter({preserve_whitespace = false})

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)

local level = 0
local function dump_scope(scope)
    print(("\t"):rep(level) .. "{")
    for _, v in ipairs(scope.upvalues) do
        local key = tostring(v.key)
        print(("\t"):rep(level+1) .. "LET " .. key .. " = " .. tostring(v.val and v.val:Render() or nil))
        if v.mutations then
            for _, v in ipairs(v.mutations) do
                print(("\t"):rep(level+2) .. "SET " .. tostring(v.val and v.val:Render() or nil))
            end
        end
        if v.usage then
            for _, v in ipairs(v.usage) do
                print(("\t"):rep(level+2) .. "USE " .. tostring(v.val and v.val:Render() or nil))
            end
        end
    end

    for _, scope in ipairs(scope.children) do
        level = level + 1
        dump_scope(scope)
        level = level - 1
    end
    print(("\t"):rep(level) .. "}")
end

dump_scope(ps:GetScope())

do return end

local function lol(a)
    a.lol = 10
    print(a)
end