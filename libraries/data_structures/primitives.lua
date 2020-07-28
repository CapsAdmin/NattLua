local ffi = require("ffi")

ffi.cdef([[
    void *realloc(void *, size_t);
    void *malloc(size_t);
    void free(void *);
]])

return {
    s8 = ffi.typeof("int8_t"),
    u8 = ffi.typeof("uint8_t"),
    s16 = ffi.typeof("int16_t"),
    u16 = ffi.typeof("uint16_t"),
    s32 = ffi.typeof("int32_t"),
    u32 = ffi.typeof("uint32_t"),
    s64 = ffi.typeof("int64_t"),
    u64 = ffi.typeof("uint64_t"),
    f32 = ffi.typeof("float"),
    f64 = ffi.typeof("double"),
    ssize = ffi.typeof("intptr_t"),
    usize = ffi.typeof("uintptr_t"),
    pointer = function(val)
        return ffi.typeof("$ *", val)
    end,
}
