local T = require("test.helpers")
local analyze_old = T.RunCode

local function analyze(c)
	return analyze_old([=[
			local ffi = require("ffi")
			ffi.C = {}	
		]=] .. c)
end

analyze[=[
	local ctype = ffi.typeof([[struct {
		uint32_t foo;
		uint8_t uhoh;
		uint64_t bar1;
	}]])

	local struct = ctype()
	
	attest.subset_of<|{
		foo = number,
		uhoh = number,
		bar1 = number,
	}, typeof struct|>
]=]
analyze[=[
	local ctype = ffi.typeof([[struct {
		uint32_t foo;
		uint8_t uhoh;
		uint64_t bar1;
	}]])


	local box = ffi.typeof("$[1]", ctype)

	local struct = box()
	
	attest.subset_of<|{
		[0] = {
			foo = number,
			uhoh = number,
			bar1 = number,
		}
	}, typeof struct|>
]=]
analyze[=[
	ffi.cdef("typedef size_t lol;")

	ffi.cdef([[
		struct foo {int bar;};
		struct foo {uint8_t bar;};
		int foo(int, bool, lol);
	]])

	attest.equal<|typeof ffi.C.foo, function=(number, boolean, number)>(number) |>
]=]
analyze[=[
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
			obj:Delete(types.ConstString("__call"))
			new_union:AddType(obj)
		end
		return new_union
	end

	local union = remove_call_function(val)

	attest.equal<|typeof union, {foo = number, bar2 = number} | {foo = number, bar3 = number} | {foo = number, uhoh = number, bar1 = number}|>
]=]
analyze[=[
	local ctype = ffi.typeof("struct { const char *foo; }")
	attest.equal(ctype.foo, _ as nil | ffi.get_type<|"const char*"|>)
]=]
analyze[=[
	local struct
	local LINUX = jit.os == "Linux"
	local X64 = jit.arch == "x64"

	if LINUX then
		ffi.cdef("void foo(int a);")
		attest.equal<|typeof ffi.C.foo, function=(number)>((nil)) |>
	else
		if X64 then
			ffi.cdef("void foo(const char *a);")
			attest.equal<|typeof ffi.C.foo, function=(string | nil | ffi.typeof<|"const char*"|>)>((nil)) |>
		else
			ffi.cdef("int foo(int a);")
			attest.equal<|typeof ffi.C.foo, function=(number)>((number))|>
		end	
	end

	attest.equal<|typeof ffi.C.foo, function=(number)>((nil)) | function=(number)>((number)) | function=(nil | string | ffi.typeof<|"const char*"|>)>((nil)) |>
]=]
analyze[=[
	ffi.cdef("void foo(void *ptr, int foo, const char *test);")

	ffi.C.foo(nil, 1, nil)
	ffi.C.foo(nil, 1, "")
]=]
analyze[=[
	local ctype = ffi.typeof("struct { int foo; }")

	local cdata = ctype({})

	attest.equal<|(typeof cdata).foo, number|>
]=]
analyze[=[
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

		function meta:__new(file_name: string, mode: ref ("write" | "read" | "append"))
			mode = translate_mode[mode]
			attest.equal<|file_name, string|>
			attest.equal<|mode, "w"|>
			local f = ffi.C.fopen(file_name, mode)

			if f == nil then return nil, "cannot open file" end

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
		attest.equal<|int, number|>
	end
]=]
analyze[=[	
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
	attest.equal(lol.u6_addr.u6_addr16, _ as FFIArray<|8, number|>)
]=]
analyze[=[
	ffi.cdef[[
		typedef size_t SOCKET;
	]]
	
	local num = ffi.new("SOCKET", -1)
	attest.equal<|num, number|>
]=]
analyze[=[
	local buffer = ffi.new("char[?]", 5)
	attest.equal<|buffer, FFIArray<|5, number|>|>

	local buffer = ffi.new("char[8]")
	attest.equal<|buffer, FFIArray<|8, number|>|>
]=]
analyze[[
	if _ as boolean then
		local function foo()
			ffi.cdef("void test()")
			if _ as boolean then
				local function test()
					local x = ffi.C.test
					attest.equal(x, _ as function=()>(nil))
				end
				test()
			end
		end
		foo()
	end

]]
analyze[=[
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
analyze[[
	ffi.cdef("typedef struct ac_t ac_t;")
	attest.equal(ffi.C.ac_t, ffi.C.ac_t)

	local ptr = ffi.new("ac_t*")
	if ptr then
		ptr = ptr + 1
		ptr = ptr - 1
	end
]]
analyze[[
	local newbuf = ffi.new("char [?]", _ as number)
	attest.equal(newbuf, _ as FFIArray<|number, number|>)
]]
analyze[[
	local gbuf_n = 1024
	local gbuf = ffi.new("char [?]", gbuf_n)
	gbuf = gbuf + 1
	attest.equal(gbuf, gbuf)
]]
analyze[==[
	ffi.cdef([[
		struct addrinfo {
			bool foo;
			struct addrinfo *ai_next;
		};
	]])
	
	local addrinfo = ffi.new("struct addrinfo")
	
	attest.equal(addrinfo.foo, _ as boolean)

	assert(addrinfo.ai_next)
	attest.equal(addrinfo.ai_next.foo, _ as boolean)
]==]
analyze[==[
	ffi.cdef([[
		uint32_t FormatMessageA(
			uint32_t dwFlags,
			va_list *Arguments
		);
	]])
	
	attest.equal(ffi.C.FormatMessageA(0, nil, true, true, false, {}, "LOL"), _ as number)

]==]
analyze[=[
	ffi.cdef[[
		struct sockaddr {
			uint8_t sa_len;
			uint8_t sa_family;
			char sa_data[14];
		};
	
		struct sockaddr_in {
			uint8_t sin_len;
			uint8_t sin_family;
			uint16_t sin_port;
			char sin_zero[8];
		};
	]]
	
	
	local a = ffi.new("struct sockaddr_in")
	local b = ffi.cast("struct sockaddr *", a)
	attest.equal<|b | nil,  nil | ffi.typeof("struct sockaddr *")|>
	

]=]
analyze[=[
	ffi.cdef[[
		struct foo {
			int a;
			int b;
		};
	]]
	
	local box = ffi.new("struct foo[1]")
	
	attest.equal(box[0], _ as {a = number, b = number})
]=]
analyze[[
	local str_v = ffi.new("const char *[?]", 1)

	attest.equal(str_v, _ as FFIArray<|1, ffi.typeof<|"const char*"|> | nil | string|>)
]]
analyze[[
	ffi.cdef([=[
		struct foo {
			char *str;
		}
	]=])
	local foo = ffi.new("struct foo") as ffi.get_type<|"struct foo*"|> ~ nil

	if foo.str then ffi.string(foo.str) end
]]
analyze[=[
    ffi.cdef([[
        struct subtest {
            int sa_data;
        };
        struct test {
            struct subtest * ai_addr;
        };
    ]])
    local type AddressInfo = {
        addrinfo = ffi.get_type<|"struct test*"|> ~ nil,
    }
    
    local function addrinfo_get_ip(self: AddressInfo)
        if self.addrinfo.ai_addr == nil then return nil end
    
        local x = self.addrinfo.ai_addr.sa_data
        attest.equal(x, _ as number)
    end
    
    local info = {} as AddressInfo
    addrinfo_get_ip(info)  
]=]
analyze[[
	local x = tostring(_  as FFIArray<|
		1,
		FFIArray<|
			2,
			FFIPointer<|
				FFIPointer<|
					function=(FFIPointer<|FFIType<|"char"|>|>)>(FFIPointer<|FFIArray<|3, FFIArray<|4, FFIPointer<|FFIType<|"unsigned long long"|>|>|>|>|>)
				|>
			|>
		|>
	|>)
	attest.equal(
		x,
		"Array1(Array2(Pointer(Pointer(function=(Pointer(number),)>(Pointer(Array3(Array4(Pointer(number)))),)))))"
	)
]]