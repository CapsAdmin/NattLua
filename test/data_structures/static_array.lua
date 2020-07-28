local StaticArrayType = require("libraries.data_structures.static_array")
local u8 = require("libraries.data_structures.primitives").u8


local UInt8Array10 = StaticArrayType(u8, 10)
local arr = UInt8Array10:new()
assert(#arr == 10)
arr:Set(5, 44)
assert(arr:Get(5) == 44)