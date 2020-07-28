local ArrayType = require("libraries.data_structures.array")
local u32 = require("libraries.data_structures.primitives").u32

local Uint32Array = ArrayType(u32)

local arr = Uint32Array:new(10)

assert(#arr == 10)

for i = 0, 9 do
    arr:Set(i, 1337)
end

for i = 0, 9 do
    assert(arr:Get(i) == 1337)
end

arr:Set(5, 777)

assert(#arr == 10)

assert(arr:Get(5) == 777)

local ok, err = pcall(function() arr:Set(11, 5) end)
assert(ok == false)
assert(err:find("out of bounds") ~= nil)

local ok, err = pcall(function() arr:Set(-1, 5) end)
assert(ok == false)
assert(err:find("out of bounds") ~= nil)


arr:Set(5, 1)
arr:Set(6, 2)
arr:Set(7, 3)

local view_slice = arr:SliceView(5, 7)

assert(view_slice:Get(0) == 1)
assert(view_slice:Get(1) == 2)
assert(view_slice:Get(2) == 3)

view_slice:Set(1, 666)

assert(view_slice:Get(1) == 666)
assert(arr:Get(6) == 666)

local slice = arr:Slice(5, 7)

assert(slice:Get(0) == 1)
assert(slice:Get(1) == 666)
assert(slice:Get(2) == 3)

slice:Set(1, 2)

assert(slice:Get(1) == 2)

assert(view_slice:Get(1) == 666)