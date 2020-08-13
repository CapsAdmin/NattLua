local Struct = require("libraries.data_structures.struct")
local DynamicArrayType = require("libraries.data_structures.dynamic_array")
local u32 = require("libraries.data_structures.primitives").u32

local MyStruct = Struct({
    {"index", u32},
    {"counter", u32},
    {"self", "self *"},
}, "lol")

local len = 1000
local MyArray = DynamicArrayType(MyStruct)

--require("jit.dump").on(nil, "-")

local arr = MyArray()

for i = 1, len do
    local t = MyStruct()
    t.index = 1337 + i
    t.counter = i - 1
    arr:Push(t)
end

--require("jit.dump").off()

assert(arr:Get(333).index == 1671)
assert(arr:Get(333).counter == 333)