local DynamicArrayType = require("libraries.data_structures.dynamic_array")
local u32 = require("libraries.data_structures.primitives").u32

local Uint32Array = DynamicArrayType(u32)

local arr = Uint32Array:new()

assert(#arr == 0)

for i = 0, 9 do
    arr:Push(10 + i)
    assert(#arr == i+1)
end

for i = 0, 9 do
    assert(arr:Get(i) == 10 + i)
end

arr:Set(5, 777)

assert(#arr == 10)

assert(arr:Get(5) == 777)

arr:Set(1111, 5)

assert(arr:Get(1111) == 5)

assert(arr.len >= 1111)

local ok, err = pcall(function() arr:Set(-1111, 5) end)
assert(ok == false)
assert(err:find("out of bounds") ~= nil)