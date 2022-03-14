local T = require("test.helpers")
local analyze = T.RunCode
analyze[[
    local function foo(): number, number
        if math.random() > 0.5 then
            return foo()
        end
        return 2, 1
    end
    
    attest.equal(foo(), _ as (number, number))
]]
analyze(
	[[
    local function foo(): number, number
        if math.random() > 0.5 then
            return foo()
        end
        return nil, 1
    end
]],
	"nil is not the same type as number"
)
