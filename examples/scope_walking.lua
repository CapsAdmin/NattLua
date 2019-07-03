local util = require("oh.util")
local oh = require("oh.oh")
local code = io.open("oh/parser.lua"):read("*all")

local tk = oh.Tokenizer(code)
local ps = oh.Parser()
local em = oh.LuaEmitter({preserve_whitespace = false})

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)

local level = 0
local function dump_scope(scope)
    print(("\t"):rep(level) .. "{")
    for _, v in ipairs(scope.upvalues) do
        print(("\t"):rep(level) .. tostring(v.key) .. " = " .. tosring(v.val))
    end

    for _, scope in ipairs(scope.children) do
        level = level + 1
        dump_scope(scope)
        level = level - 1
    end
    print(("\t"):rep(level) .. "}")
end
dump_scope(ps:GetScope())