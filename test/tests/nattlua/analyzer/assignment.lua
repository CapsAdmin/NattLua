local LString = require("nattlua.types.string").LString
analyze[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

attest.equal(a, 1)
attest.equal(b, 2)
attest.equal(c, 3)

attest.equal(d, 4)
attest.equal(e, 5)
attest.equal(f, 6)

local   vararg_1 = ... as any
        vararg_2 = ... as any

attest.equal(vararg_1, _ as any)
attest.equal(vararg_2, _ as any)

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

attest.equal(A, 1)
attest.equal(B, 4)
attest.equal(C, nil)
attest.equal(D, nil)

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

attest.equal(z, 1)
attest.equal(x, 2)
attest.equal(y, 3)
attest.equal(æ, 4)
attest.equal(ø, 5)
attest.equal(å, 6)

A, B, C, D = nil, nil, nil, nil

]]
analyze(
	[[
    local type Foo = {
        a = 1,
        b = 2,
    }

    local a: Foo = { a = 1 }    
]],
	" is missing from "
)
analyze(
	[[
    local type Person = unique {
        id = number,
        name = string,
    }
    
    local type Pet = unique {
        id = number,
        name = string,
    }
    
    local dog: Pet = {
        id = 1,
        name = "pete"
    }
    
    local human: Person = {
        id = 6,
        name = "persinger"
    }
    
    local c: Pet = human    
]],
	"is not the same unique type as"
)
analyze([[
    local type test = unique 1
]], "must be a table")

test("runtime reassignment", function()
	local v = analyze[[
        local a = 1
        do
            a = 2
        end
    ]]:GetLocalOrGlobalValue(LString("a"))
	equal(v:GetData(), 2)
	local v = analyze[[
        local a = 1
        if true then
            a = 2
        end
    ]]:GetLocalOrGlobalValue(LString("a"))
	equal(v:GetData(), 2)
end)

analyze([[
    local x <const> = 1
    x = 2
]], "cannot assign to const variable")
analyze[[
local analyzer function normalize(obj: any)
	local temp = {}

	for i = 1, 10 do
		local v = obj:GetAtTupleIndex2(i)

		if not v then break end

		temp[i] = v
	end

	return types.Tuple(temp)
end

attest.equal<|
	normalize<|(1, 2, 3, (nil, false, "foo") | 1337) | (nil, false, "bar")|>,
	(1 | nil, 2 | false, "bar" | 3, 1337 | nil, false | nil, "foo" | nil)
|>
attest.equal<|normalize<|((1, nil, 2))|>, (1, nil, 2)|>
attest.equal<|normalize<|((1, number, 2) | (string,))|>, (1 | string, nil | number, 2 | nil)|>
attest.equal<|normalize<|((1, 2) | (string,))|>, (1 | string, nil | 2)|>
attest.equal<|normalize<|((1, 2) | string)|>, (1 | string, nil | 2)|>
attest.equal<|normalize<|((1, 2) | (nil, nil))|>, (1 | nil, nil | 2)|>
attest.equal<|normalize<|((1, 2, 3) | (nil, nil))|>, (1 | nil, nil | 2, 3 | nil)|>
attest.equal<|normalize<|((1) | (2))|>, (1 | 2)|>
attest.equal<|normalize<|((1) | ())|>, (1 | nil)|>
attest.equal<|normalize<|(() | ())|>, ()|>
attest.equal<|normalize<|(1 | (2) | (3))|>, (1 | 2 | 3)|>
attest.equal<|normalize<|(1 | (2 | (3, 4)) | (3))|>, (1 | 2 | 3, nil | 4)|>
attest.equal<|normalize<|()|>, ()|>
attest.equal<|normalize<|((1, 2) * 2)|>, (1, 2, 1, 2)|>
attest.equal<|normalize<|(1, 2, (number,) * 2)|>, (1, 2, number, number)|>
]]

analyze[[
local function foo(...)
	attest.equal<|..., (1,2,((any,)*inf,))|>
end

local function bar(...)
	foo(1,2,...)
end
]]
