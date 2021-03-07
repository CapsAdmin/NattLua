function table.destructure(tbl, fields, with_default)
    local out = {}
    for i, key in ipairs(fields) do
        out[i] = tbl[key]
    end
    if with_default then
        table.insert(out, 1, tbl)
    end
    return table.unpack(out)
end

function table.mergetables(tables)
    local out = {}
    for i, tbl in ipairs(tables) do
        for k,v in pairs(tbl) do
            out[k] = v
        end
    end
    return out
end

function table.spread(tbl)
    if not tbl then
        return nil
    end

    return table.unpack(tbl)
end

function LSX(tag, constructor, props, children)
    local e = constructor and constructor(props, children) or {
        props = props,
        children = children,
    }
    e.tag = tag
    return e
end

local tprint = require("nattlua.other.tprint")

function table.print(...)
    return tprint(...)
end
IMPORTS = IMPORTS or {}
IMPORTS['example_project/src/shared_cdef.nlua'] = function(...) -- just to show import

return {
    cdecl = [[
        struct DIR {}
    ]]
} end
--[==[-- this will use some reflection api to track types from ffi.cdef
import_type<|"typed_ffi.nlua"|>]==]
local   cdecl  =table.destructure(( IMPORTS['example_project/src/shared_cdef.nlua']("shared_cdef.nlua")), {"cdecl"})
local ffi = require("ffi")

ffi.cdef(cdecl)

-- both of these branches should hit, because jit.os == "OSX" is uncertain (jit.os is a union of "OSX" | "Linux" | "Windows", etc)

if jit.os == "OSX" then
    -- this will create a copy of the current cdef environment that is only available within this scope
    ffi.cdef([[
        struct dirent {
            int foo;
            int bar;
        };

        void open(struct dirent, struct DIR);
    ]])--[==[

    type_assert<|typeof ffi.C.open, (function({foo=number, bar=number}, {}): nil)|>]==]
else
    -- same goes for this scope
    ffi.cdef([[
        struct dirent {
            const char* foo;
            const char* bar;
        };

        void open(struct dirent, struct DIR);
    ]])--[==[
    
    type_assert<|typeof ffi.C.open, (function({foo={[number] = number}, bar={[number] = number}}, {}): nil)|>]==]
end--[==[

-- here we see a union of both scopes above
type_assert<|typeof ffi.C.open, bit.bor( (function({foo={[number] = number}, bar={[number] = number}}, {}): nil),  (function({foo=number, bar=number}, {}): nil)) |>]==]