local oh = require("oh.oh")
local test = require("tests.test")
local tprint = require("oh.util").TablePrint

local code = [[

    a = -1+2+3()()[1]

]]

local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code))))


local expr = ast:FindStatementsByType("assignment")[1].expressions_right[1]
local META = getmetatable(expr)


do
    local table_insert = table.insert
    local function expand(node, tbl)
        
        if node.kind:sub(1, #"postfix") == "postfix" then
            table_insert(tbl, node.kind:sub(#"postfix"+2))
        else
            print(node.kind)
            table_insert(tbl, node.value.value)
        end

        if node.left then
            table_insert(tbl, "(")
            expand(node.left, tbl)
        end
        
        
        if node.right then
            table_insert(tbl, " ")
            expand(node.right, tbl)
            table_insert(tbl, ")")
        end

        if node.kind:sub(1, #"postfix") == "postfix" then
            table_insert(tbl, ", ...)")
        end

        return tbl
    end
    
    function META:DumpPresedence()
        local list = expand(self, {})
        return table.concat(list)
    end
end

print(expr:DumpPresedence())

do return end

for l,op,r in expr:Walk() do
    print(l, op, r)
end
