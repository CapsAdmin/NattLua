local ffi = require("ffi")
local HashTableType = require("nattlua.util.data_structures.hash_table")
local f64 = require("nattlua.util.data_structures.primitives").f64

math.randomseed(0)
local keys = {}
local done = {}
for i = 1, 100 do
    local str = {}
    for i = 1, math.random(1, 30) do
        str[i] = string.char(math.random(32,128))
    end
    str = table.concat(str)
    if not done[str] then
        table.insert(keys, str)
        done[str] = true
    end
end

local function key()
    return keys[math.random(1, #keys)]
end

local DoubleHashMap = HashTableType("const char *", f64)
local map = DoubleHashMap(500)
-- map = LuaTable()

local MAX = 500
local unique_keys = {}
for i = 1, MAX do
    unique_keys[i] = keys[(i%#keys) + 1] .. "-" .. i
end

--local time = os.clock()
for i = 1, MAX do
    local val = i/MAX
    local key = unique_keys[i]

    map:Set(key, val)

    if map:Get(key) ~= val then
        print("BUCKET: ")
        local arr = map:GetBucket(key)
        for i = 0, #arr - 1 do
            print("[" .. i .. "] " .. ffi.string(arr:Get(i).key) .. " = " .. tostring(arr:Get(i).val))
        end
        error("key " .. key .. " = " .. tostring(map:Get(key)) .. " does not equal " .. val)
    end
end
--print(os.clock() - time .. " seconds")