local T = require("test.helpers")
local run = T.RunCode

pending([[

    local operators = {
        ["-"] = function(l: number)
            return -l
        end,
        ["~"] = function(l: number)
            return bit.bnot(l)
        end,
    }
    local function PrefixOperator(op#: keysof<| operators |>)
        print(operators)
        if math.random() > 0.5 then
            print(operators[op])
        end
    end
    
    
    local operators = {
        1,2,3
    }
    
    PrefixOperator("-")
]])
