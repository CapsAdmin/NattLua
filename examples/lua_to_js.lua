local oh = require("oh")
local LuaEmitter = require("oh.lua.javascript_emitter")
local code = io.open("oh/parser.lua"):read("*all")

code = [==[

local META = {}
META.__index = META

function META:Test(a,b,c)
    print(self, a,b,c)
end

function META.__add(a,b)
    return 42
end

local self = setmetatable({}, META)

print("===",1,23)
self:Test(1,2,3)

print(self + self)

local a = GLOBAL

local test = {foo = {}}
local aa = {bb = {cc = 1}}

test.foo.bar = aa.bb.cc
print(test.foo.bar)

local c = {}
table.insert(c, 1)
print(a)

]==]

local ast = assert(assert(oh.Code(code):Parse()):Analyze()).SyntaxTree

local em = LuaEmitter()

local f = loadstring(code)
if f then pcall(f) end

local code = em:BuildCode(ast)
code = ([[

let globalThis = {}

globalThis.print = console.log;

let metatables = new Map()

globalThis.table = {}
globalThis.table.insert = (tbl, i, val) => {
    if (!val) {
        val = i
    }

    tbl.push(val)
}

globalThis.setmetatable = (obj, meta) => {
    metatables.set(obj, meta)
    return obj
}
globalThis.getmetatable = (obj) => {
    return metatables.get(obj)
}

let nil = undefined

let OP = {}
{
    OP["="] = (obj, key, val) => {
        obj[key] = val
    }

    OP["."] = (l, r) => {
        if (l[r]) {
            return l[r]
        }

        let lmeta = globalThis.getmetatable(l)
        
        if (lmeta && lmeta.__index) {
            if (lmeta.__index === lmeta) {
                return lmeta[r]
            }

            return lmeta.__index(l, r)
        }

        return nil
    }

    let self = undefined

    $OPERATORS$

    OP[":"] = (l, r) => {
        self = l
        return OP["."](l,r)
    }

    OP["call"] = (obj, ...args) => {
        if (!obj) {
            throw "attempt to call a nil value"
        }
        if (self) {
            let a = self
            self = undefined
            return obj.apply(obj, [a, ...args])
        }

        return obj.apply(obj, args)
    }
}
]]):gsub("%$OPERATORS%$", function()
    
    local operators = {
        ["+"] = "__add",
        ["-"] = "__sub",
        ["*"] = "__mul",
        ["/"] = "__div",
        ["/idiv/"] = "__idiv",
        ["%"] = "__mod",
        ["^"] = "__pow",
        ["&"] = "__band",
        ["|"] = "__bor",
        ["<<"] = "__lshift",
        [">>"] = "__rshift",
    }

    local code = ""

    for operator, name in pairs(operators) do
        code = code .. [[
            OP["]] .. operator ..[["] = (l,r) => {
                let lmeta = globalThis.getmetatable(l)
                if (lmeta && lmeta.]]..name..[[) {
                    return lmeta.]]..name..[[(l, r)
                }
        
                let rmeta = globalThis.getmetatable(r)
        
                if (rmeta && rmeta.]]..name..[[) {
                    return rmeta.]]..name..[[(l, r)
                }
        
                return l ]]..operator..[[ r
            }
        ]]
    end

    return code
end) .. code
print(code)

local f = io.open("temp.js", "wb")
f:write(code)
f:close()

os.execute("node temp.js")

--os.remove("temp.js")