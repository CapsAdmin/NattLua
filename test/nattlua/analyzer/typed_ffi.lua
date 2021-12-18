local T = require("test.helpers")
local run = T.RunCode

run[=[
	ffi.C = {}

	local ctype = ffi.typeof([[struct {
		uint32_t foo;
		uint8_t uhoh;
		uint64_t bar1;
	}]])

	local struct = ctype()
	
	types.assert_subset<|typeof struct, {
		foo = number,
		uhoh = number,
		bar1 = number,
	}|>
]=]

run[=[
	ffi.C = {}

	local ctype = ffi.typeof([[struct {
		uint32_t foo;
		uint8_t uhoh;
		uint64_t bar1;
	}]])


	local box = ffi.typeof("$[1]", ctype)
	
	local struct = box()
	
	types.assert_subset<|typeof struct, {
		[number] = {
			foo = number,
			uhoh = number,
			bar1 = number,
		}
	}|>
]=]

run[=[
	ffi.C = {}

	ffi.cdef("typedef size_t lol;")

	ffi.cdef([[
		struct foo {int bar;};
		struct foo {uint8_t bar;};
		int foo(int, bool, lol);
	]])

	types.assert<|typeof ffi.C.foo, function=(number, boolean, number)>(number) |>
]=]

run[=[
	ffi.C = {}

	local struct
	local LINUX = jit.os == "Linux"
	local X64 = jit.arch == "x64"

	if LINUX then
		struct = ffi.typeof([[struct {
			uint32_t foo;
			uint8_t uhoh;
			uint64_t bar1;
		}]])
	else
		if X64 then
			struct = ffi.typeof([[struct {
				uint32_t foo;
				uint64_t bar2;
			}]])
		else
			struct = ffi.typeof([[struct {
				uint32_t foo;
				uint32_t bar3;
			}]])
		end	
	end

	local val = struct()

	local analyzer function remove_call_function(union: any)
		local new_union = types.Union({})
		for _, obj in ipairs(union:GetData()) do
			obj:Delete(types.LString("__call"))
			new_union:AddType(obj)
		end
		return new_union
	end

	local union = remove_call_function(val)

	types.assert<|typeof union, {foo = number, bar2 = number} | {foo = number, bar3 = number} | {foo = number, uhoh = number, bar1 = number}|>
]=]

run[=[
	ffi.C = {}
	local ctype = ffi.typeof("struct { const char *foo; }")
	types.assert(ctype.foo, _ as string | nil | {[number] = number})
]=]


run[=[
	ffi.C = {}
	local struct
	local LINUX = jit.os == "Linux"
	local X64 = jit.arch == "x64"

	if LINUX then
		ffi.cdef("void foo(int a);")
		types.assert<|typeof ffi.C.foo, function=(number)>((nil)) |>
	else
		if X64 then
			ffi.cdef("void foo(const char *a);")
			types.assert<|typeof ffi.C.foo, function=(string | nil | {[number] = number})>((nil)) |>
		else
			ffi.cdef("int foo(int a);")
			types.assert<|typeof ffi.C.foo, function=(number)>((number))|>
		end	
	end

	types.assert<|typeof ffi.C.foo, function=(number)>((nil)) | function=(number)>((number)) | function=(string | nil | {[number] = number})>((nil)) |>
]=]

run[=[
	ffi.C = {}
	ffi.cdef("void foo(void *ptr, int foo, const char *test);")

	ffi.C.foo(nil, 1, nil)
	ffi.C.foo(nil, 1, "")
]=]

run[=[
	ffi.C = {}
	local ctype = ffi.typeof("struct { int foo; }")

	local cdata = ctype({})

	types.assert<|(typeof cdata).foo, number|>
]=]

run[=[
    ffi.C = {}

	local handle = ffi.typeof("struct {}")
	local pointer = ffi.typeof("$*", handle)

	local meta = {}
	meta.__index = meta
	do
		local translate_mode = {
			read = "r",
			write = "w",
			append = "a",
		}

		ffi.cdef("$ fopen(const char *, const char *);", pointer)
		function meta:__new(file_name: string, mode: "write" | "read" | "append")
			mode = translate_mode[mode]

			types.assert<|file_name, "YES"|>
			types.assert<|mode, "w"|>

			local f = ffi.C.fopen(file_name, mode)
			
			if f == nil then
				return nil, "cannot open file"
			end
			
			return f
		end

		function meta:__gc()
			self:close()
		end

		ffi.cdef("int fclose($);", pointer)
		function meta:close()
			return ffi.C.fclose(self)
		end
	end

	ffi.metatype(handle, meta)

	local f = handle("YES", "write")

	if f then
		local int = f:close()
		types.assert<|int, number|>
	end
]=]

run[=[	
    ffi.C = {}
	ffi.cdef([[
		struct in6_addr {
            union {
                uint8_t u6_addr8[16];
                uint16_t u6_addr16[8];
                uint32_t u6_addr32[4];
            } u6_addr;
        };
	]])

	local lol = ffi.new("struct in6_addr")

	types.assert(lol.u6_addr.u6_addr16, _ as {[number] = number})
]=]

run[=[
	ffi.cdef[[
		typedef size_t SOCKET;
	]]
	
	local num = ffi.new("SOCKET", -1)
	types.assert<|num, number|>
]=]

run[=[
	local buffer = ffi.new("char[?]", 5)
	types.assert<|buffer, {[number] = number}|>

	local buffer = ffi.new("char[8]")
	types.assert<|buffer, {[number] = number}|>
]=]

run[[
	ffi.C = {}

	if _ as boolean then
		local function foo()
			ffi.cdef("void test()")
			if _ as boolean then
				local function test()
					local x = ffi.C.test
					types.assert(x, _ as function=()>(nil))
				end
				test()
			end
		end
		foo()
	end

]]

run[=[
	ffi.C = {}

	if math.random() > 0.5 then
		ffi.cdef([[
			void readdir();
		]])
	else
		ffi.cdef([[
			void readdir();
		]])
	end
	
	ffi.C.readdir()
	
]=]