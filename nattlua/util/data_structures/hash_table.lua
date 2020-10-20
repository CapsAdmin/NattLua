local ffi = require("ffi")
local Struct = require("nattlua.util.data_structures.struct")
local DynamicArrayType = require("nattlua.util.data_structures.dynamic_array")
local ArrayType = require("nattlua.util.data_structures.array")

return function(key_type, val_type)

    local KeyVal = Struct({
        {"key", key_type},
        {"val", val_type},
    })

    local KeyValArray = DynamicArrayType(KeyVal)
    local Array = ArrayType(KeyValArray)

    local ctype = ffi.typeof("struct { $ array; }", Array)

    local META = {}
    META.__index = META

    local function address_hash(val)
        local address = ffi.cast("uint64_t", ffi.cast("void *", val))
        return tonumber(address)
    end

    local function hash(ptr, max)
        if type(ptr) == "string" then
            local idx = 0
            for i = 1, #ptr do
                idx = idx + ptr:byte(i)
            end
            math.randomseed(idx)
            return math.random(0, max)
        end
        return address_hash(ptr)
    end

    function META:Hash(key)
        local max = self.array.len
        local hash = hash(key, max)
        local index = hash % max

        return self:OpenIndex(index, key)
    end

    function META:IsBucketOccupied(index)
        return self.array:Get(index):Get(0) ~= nil
    end

    function META:OpenIndex(index, key)
        local search = index

         while self:IsBucketOccupied(search) do

            local arr = self.array:Get(search)

            for i = 0, #arr - 1 do
                local keyval = arr:Get(i)
                if keyval.key == key then
                    return search, i
                end
            end

            search = search + 1

            if search >= self.array.len then
                search = 0
            end

            if search == index then
                break
            end
        end

        return search
    end

    function META:Set(key, val)
        local index, sub_index = self:Hash(key)

        local keyval_array = self.array:Get(index)

        if sub_index then
            keyval_array:Get(sub_index).val = val
            return
        end

        if keyval_array:Get(0) ~= nil then
            for i = 0, #keyval_array-1 do
                local keyval = keyval_array:Get(i)
                if keyval.key == key then
                    keyval.val = val
                    return
                end
            end
        end

        local keyval = KeyVal()
        keyval.key = key
        keyval.val = val

        keyval_array:Push(keyval)
    end

    function META:GetBucket(key)
        return self.array:Get(self:Hash(key))
    end

    function META:Get(key)
        local index, sub_index = self:Hash(key)
        local keyval_array = self.array:Get(index)

        if sub_index then
            return keyval_array:Get(sub_index).val
        end

        for i = 0, #keyval_array - 1 do
            local keyval = keyval_array:Get(i)
            if keyval.key == key then
                return keyval.val
            end
        end

        return nil
    end

    function META:GetCollisionRate()
        local count = 0
        local total = 0
        local holes = 0
        for i = 0, #self.array - 1 do
            local arr = self.array:Get(i)
            if arr:Get(0) == nil then
                holes = holes + 1
            else
                count = count + tonumber(#arr)
                total = total + 1
            end
        end
        return count / total, holes
    end

    function META:DumpData()
        print("===")
        for i = 0, #self.array - 1 do
            io.write(i .. ": ")
            for i2 = 0, #self.array:Get(i) - 1 do
                local keyval = self.array:Get(i):Get(i2)
                io.write(tostring(ffi.string(keyval.key)), " | ")
            end
            io.write("\n")
        end
    end

    function META:__new(len)
        self.array = Array(len or 500000)
    end

    ffi.metatype(ctype, META)

    return ctype
end