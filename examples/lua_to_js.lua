local nl = require("nl")
local LuaEmitter = require("nattlua.lua.javascript_emitter")
local code = io.open("nl/base_parser.lua"):read("*all")



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

code = [[
sun = {}
jupiter = {}
saturn = {}
uranus = {}
neptune = {}

local sqrt = math.sqrt

local PI = 3.141592653589793
local SOLAR_MASS = 4 * PI * PI
local DAYS_PER_YEAR = 365.24
sun.x = 0.0
sun.y = 0.0
sun.z = 0.0
sun.vx = 0.0
sun.vy = 0.0
sun.vz = 0.0
sun.mass = SOLAR_MASS
jupiter.x = 4.84143144246472090e+00
jupiter.y = -1.16032004402742839e+00
jupiter.z = -1.03622044471123109e-01
jupiter.vx = 1.66007664274403694e-03 * DAYS_PER_YEAR
jupiter.vy = 7.69901118419740425e-03 * DAYS_PER_YEAR
jupiter.vz = -6.90460016972063023e-05 * DAYS_PER_YEAR
jupiter.mass = 9.54791938424326609e-04 * SOLAR_MASS
saturn.x = 8.34336671824457987e+00
saturn.y = 4.12479856412430479e+00
saturn.z = -4.03523417114321381e-01
saturn.vx = -2.76742510726862411e-03 * DAYS_PER_YEAR
saturn.vy = 4.99852801234917238e-03 * DAYS_PER_YEAR
saturn.vz = 2.30417297573763929e-05 * DAYS_PER_YEAR
saturn.mass = 2.85885980666130812e-04 * SOLAR_MASS
uranus.x = 1.28943695621391310e+01
uranus.y = -1.51111514016986312e+01
uranus.z = -2.23307578892655734e-01
uranus.vx = 2.96460137564761618e-03 * DAYS_PER_YEAR
uranus.vy = 2.37847173959480950e-03 * DAYS_PER_YEAR
uranus.vz = -2.96589568540237556e-05 * DAYS_PER_YEAR
uranus.mass = 4.36624404335156298e-05 * SOLAR_MASS
neptune.x = 1.53796971148509165e+01
neptune.y = -2.59193146099879641e+01
neptune.z = 1.79258772950371181e-01
neptune.vx = 2.68067772490389322e-03 * DAYS_PER_YEAR
neptune.vy = 1.62824170038242295e-03 * DAYS_PER_YEAR
neptune.vz = -9.51592254519715870e-05 * DAYS_PER_YEAR
neptune.mass = 5.15138902046611451e-05 * SOLAR_MASS

local bodies = {sun,jupiter,saturn,uranus,neptune}

local function advance(bodies, nbody, dt)
  for i=1,nbody do
    local bi = bodies[i]
    local bix, biy, biz, bimass = bi.x, bi.y, bi.z, bi.mass
    local bivx, bivy, bivz = bi.vx, bi.vy, bi.vz
    for j=i+1,nbody do
      local bj = bodies[j]
      local dx, dy, dz = bix-bj.x, biy-bj.y, biz-bj.z
      local dist2 = dx*dx + dy*dy + dz*dz
      local mag = sqrt(dist2)
      mag = dt / (mag * dist2)
      local bm = bj.mass*mag
      bivx = bivx - (dx * bm)
      bivy = bivy - (dy * bm)
      bivz = bivz - (dz * bm)
      bm = bimass*mag
      bj.vx = bj.vx + (dx * bm)
      bj.vy = bj.vy + (dy * bm)
      bj.vz = bj.vz + (dz * bm)
    end
    bi.vx = bivx
    bi.vy = bivy
    bi.vz = bivz
    bi.x = bix + dt * bivx
    bi.y = biy + dt * bivy
    bi.z = biz + dt * bivz
  end
end

local function energy(bodies, nbody)
  local e = 0
  for i=1,nbody do
    local bi = bodies[i]
    local vx, vy, vz, bim = bi.vx, bi.vy, bi.vz, bi.mass
    e = e + (0.5 * bim * (vx*vx + vy*vy + vz*vz))
    for j=i+1,nbody do
      local bj = bodies[j]
      local dx, dy, dz = bi.x-bj.x, bi.y-bj.y, bi.z-bj.z
      local distance = sqrt(dx*dx + dy*dy + dz*dz)
      e = e - ((bim * bj.mass) / distance)
    end
  end
  return e
end

local function offsetMomentum(b, nbody)
  local px, py, pz = 0, 0, 0
  for i=1,nbody do
    local bi = b[i]
    local bim = bi.mass
    
    px = px + (bi.vx * bim)
    py = py + (bi.vy * bim)
    pz = pz + (bi.vz * bim)
  end
  b[1].vx = -px / SOLAR_MASS
  b[1].vy = -py / SOLAR_MASS
  b[1].vz = -pz / SOLAR_MASS
end

local N = tonumber(arg and arg[1]) or 100000
local nbody = #bodies

offsetMomentum(bodies, nbody)
io.write( string.format("%0.9f",energy(bodies, nbody)), "\n")
for i=1,N do advance(bodies, nbody, 0.01) end
io.write( string.format("%0.9f",energy(bodies, nbody)), "\n")
]]
--loadstring(code)()
cowde = [[
    local N = undefined or 1000
    print(N)
]]


codew = [[
    local a = {1,2,3}
    for i = 1, #a do
        local b = a[i]
        print(b, "?")
    end
]]
codew = [[
    print(string.format("%s %s", 1,2))
]]

codew =[[
    local a = {}
    a[1] = true
    print(a[1])
]]
local ast = assert(assert(nl.Code(code):Parse()):Analyze()).SyntaxTree

local em = LuaEmitter()

local f = loadstring(code)
if f then pcall(f) end

local code = em:BuildCode(ast)
code = ([[

let globalThis = {}

globalThis.print = console.log;
globalThis.tonumber = (str) => {
    let n = parseFloat(str)
    if (isNaN(n)) {
        return undefined
    }
    return n
};
globalThis.arg = []

globalThis.math = {}
globalThis.math.sqrt = Math.sqrt


globalThis.io = {}
globalThis.io.write = console.log

require("sprintf.js")

globalThis.string = {}
globalThis.string.format = sprintf

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
    OP["#"] = (val) => val.length
    OP["="] = (obj, key, val) => {
        obj[key] = val
    }

    OP["."] = (l, r) => {
        if (Array.isArray(l)) {
            return l[r - 1]
        }

        if (l[r] != undefined) {
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

    OP["and"] = (l, r) => l !== undefined && l !== false && r !== undefined && r !== false
    OP["or"] = (l, r) => (l !== undefined && l !== false) ? l : (r !== undefined && r !== false) ? r : undefined

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

os.execute("mkdir -p jstest/src")
os.execute("cd jstest && yarn && yarn add sprintf.js")
local f = io.open("jstest/src/test.js", "wb")
f:write(code)
f:close()

os.execute("node --trace-uncaught jstest/src/test.js")

--os.remove("temp.js")