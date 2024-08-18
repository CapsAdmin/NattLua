
analyze(
	[[
    local type contract = {}
    type contract.test = function=(number)>(string)

    local lib = {} as contract

    function lib.unknown() 

    end
]],
	"is not a subset of"
)
analyze(
	[[
    local type contract = {}
    type contract.test = function=(number)>(string)

    local lib = {} as contract

    function lib.test(lol: string) 
        return 1,2,3
    end
]],
	"number.-is not a subset of.-string"
)
analyze[[
    local type contract = {}
    type contract.test = function=(number)>(string)

    local lib = {} as contract

    function lib.test(lol) 
        attest.equal<|lol, number|>
        return "test"
    end
]]
analyze[[
    local META = {} as {[string] = any}
    META.__index = META
    
    type META.i = number
    type META.code = string
    
    attest.equal(META.i, _ as number)
    attest.equal(META.code, _ as string)
    attest.equal(META.codeawdawd, _ as any) 
]]
analyze[[
    local META = {} as {[string] = any, i = number, code = string}
    META.__index = META

    attest.equal(META.i, _ as number)
    attest.equal(META.code, _ as string)
    attest.equal(META.codeawdawd, _ as any)
]]
analyze[[
    local type Node = {
        type = any,
        kind = any,
    }
    local x: Node = {
        type = "lol",
    -- but no kind!
    }
]]