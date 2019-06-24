local oh = require("oh.oh")
local util = require("oh.util")

local code = [[
    -- It checks variables you have defined as global
    some_unused_var = 42
    local x
    
    -- Write-only variables are not considered as used.
    local y = 10
    y = 5
    
    -- A read for a modification of itself is not considered as used.
    local z = 0
    z = z + 1
    
    -- By default, unused arguments cause warnings.
    local function lol(foo)
        return 5
    end

    lol()
    
    -- Unused recursive functions also cause warnings.
    local function fact(n)
        if n < 2 then return 1 end
        return n * fact(n - 1)
    end
]]
code = "local a = (({} + 2 * 3)()+1)(1,2,3)()()"

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))

util.TablePrint(ast)

for _, node in ipairs(ast:FindByType("value")) do
    print(node:Render())
end