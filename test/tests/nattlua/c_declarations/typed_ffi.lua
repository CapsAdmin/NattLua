local analyze_old = _G.analyze

local function analyze(c)
	return analyze_old(
		[=[
			§require("nattlua.definitions.lua.ffi.main").reset()
		]=] .. c
	)
end

analyze[=[
	local ctype = ffi.typeof([[struct {
		uint32_t foo;
		uint8_t uhoh;
		uint64_t bar1;
	}]])
		

	local struct = ctype()
	attest.superset_of<|{
		foo = number,
		uhoh = number,
		bar1 = number,
	}, struct.T|>
]=]
analyze[=[
	local ctype = ffi.typeof([[struct {
		uint32_t foo;
		uint8_t uhoh;
		uint64_t bar1;
	}]])

	local box = ffi.typeof("$[1]", ctype)
	
	local struct = box()
	
	attest.superset_of<|{
		[0] = {
			foo = number,
			uhoh = number,
			bar1 = number,
		}
	}, struct.T|>
]=]
analyze[=[
	ffi.cdef("typedef size_t lol;")

	ffi.cdef([[
		struct foo {int bar;};
		struct foo {uint8_t bar;};
		int foo(int, bool, lol);
	]])

	attest.equal(ffi.C.foo, _ as function=(number|TCData<|number|>, boolean, TCData<|number|> | number)>(number))
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
	attest.equal<|val, TCType{foo = number, bar2 = number} | TCType{foo = number, bar3 = number} | TCType{foo = number, uhoh = number, bar1 = number}|>
]=]
analyze[=[
	local ctype = ffi.typeof("struct { const char *foo; }")
	attest.equal(ctype().foo, _ as nil | ffi.get_type<|"const char*"|>)
]=]
analyze[=[
	local struct
	local LINUX = jit.os == "Linux"
	local X64 = jit.arch == "x64"

	if LINUX then
		ffi.cdef("void foo(int a);")
		attest.equal(ffi.C.foo, _ as function=(number|TCData<|number|>)>())
	else
		if X64 then
			ffi.cdef("void foo(const char *a);")
			attest.equal(ffi.C.foo, _ as function=(string | nil | ffi.new<|"const char*"|>)>())
		else
			ffi.cdef("int foo(int a);")
			attest.equal(ffi.C.foo, _ as function=(number|TCData<|number|>)>(number))
		end	
	end

	attest.equal(ffi.C.foo, _ as function=(number|TCData<|number|>)>() | function=(number|TCData<|number|>)>(number) | function=(nil | string | ffi.new<|"const char*"|>)>())
]=]
analyze[=[
	ffi.cdef("void foo(void *ptr, int foo, const char *test);")

	ffi.C.foo(nil, 1, nil)
	ffi.C.foo(nil, 1, "")
]=]
analyze[=[
	local ctype = ffi.typeof("struct { int foo; }")
	local cdata = ctype({})
	attest.equal<|tonumber((typeof cdata).foo), number|>
]=]
pending[=[
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
	attest.equal(lol.u6_addr.u6_addr16, _ as TCData<|{[0..7] = number}|>)
]=]
analyze[=[
	ffi.cdef[[
		typedef size_t SOCKET;
	]]
	
	local num = ffi.new("SOCKET", -1)
	attest.equal<|tonumber(num), -1|>
]=]
analyze[=[
	local buffer = ffi.new("char[?]", 5)
	attest.equal<|buffer, TCData<|{[0..4] = number}|>|>

	local buffer = ffi.new("char[8]")
	attest.equal<|buffer, TCData<|{[0..7] = number}|>|>
]=]
analyze[[
	if _ as boolean then
		local function foo()
			ffi.cdef("void test()")
			if _ as boolean then
				local function test()
					local x = ffi.C.test
					attest.equal(x, _ as function=()>())
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
	attest.equal(newbuf, _ as TCData<|{[number] = number}|>)
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
	local next = addrinfo.ai_next
	assert(next)
	attest.equal(next.foo, _ as boolean)
]==]
analyze[==[
	ffi.cdef([[
		uint32_t FormatMessageA(
			uint32_t dwFlags,
			...
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
	attest.equal<|b, ffi.new("struct sockaddr *")|>
]=]
analyze[=[
	ffi.cdef[[
		struct foo {
			int a;
			int b;
		};
	]]
	
	local box = ffi.new("struct foo[1]")
	
	attest.equal(box[0], _ as TCData{a = number, b = number})
]=]
analyze[[
	local str_v = ffi.new("const char *[?]", 1)

	attest.equal(str_v, _ as ffi.new<|"const char*[1]"|>)
	attest.equal(str_v[0], _ as nil | ffi.new<|"const char*"|>)
]]
analyze[[
	ffi.cdef([=[
		struct foo {
			char *str;
		}
	]=])
	local foo = ffi.new("struct foo")
	local str = foo.str -- TODO, table mutations not working with ctypes
	if str then 
		ffi.string(str)
	 end
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
    
        local x = assert(assert(self.addrinfo).ai_addr).sa_data
        attest.equal(x, _ as number)
    end
    
    local info = {} as AddressInfo
    addrinfo_get_ip(info)  
]=]
analyze[=[
	local ffi = require("ffi")
	ffi.cdef[[
		struct sockaddr {
			int foo;
		};
		struct sockaddr2 {
			short a;
			short b;
		};
		int WSAAddressToStringA(struct sockaddr2 *);
	]]
	
	local srcaddr = ffi.new("struct sockaddr")
	local x = ffi.cast("struct sockaddr2 *", srcaddr)
]=]
analyze[=[
	local ffi = require("ffi")
	ffi.cdef[[
		struct pollfd {
			short fd;
			short events;
			short revents;
		};
	]]

	local M = {}

	function M.poll(
		s: ffi.new<|"struct pollfd*"|>,
	)
		local pfd = {
			fd = s.fd,
		}
		attest.equal(pfd.fd, _ as number)
	end
]=]
analyze[=[
	local t = ffi.new([[
		struct {
			int a;
			union {
			  int b;
			  float c;
			};
			int d;
		  }
	]])
	attest.equal(t.a, _ as number)
	attest.equal(t.b, _ as number)
	attest.equal(t.c, _ as number)
	attest.equal(t.d, _ as number)
]=]
pending[=[
	local meta = {}
	meta.__index = meta
	ffi.cdef[[
	struct foo {
		int x;
	};

	struct foo foo_new();
	]]

	function meta:__new()
		local self = ffi.C.foo_new()
		self.x = 10
		return self
	end

	function meta:test()
		return self.x
	end

	meta = ffi.metatype("struct foo", meta)
	local x = meta() --ffi.new("struct foo")
	attest.equal(x:test(), 10)
]=]
pending[=[
	local ffi = require("ffi")
	ffi.cdef[[
	struct OpusEncoder { int dummy; };
	struct OpusEncoder *opus_encoder_create();
	int opus_encoder_ctl(struct OpusEncoder *st);
	]]
	local Encoder = {}
	Encoder.__index = Encoder

	function Encoder:__new()
		local state = assert(ffi.C.opus_encoder_create())
		return state
	end

	function Encoder:get(id: number)
		ffi.C.opus_encoder_ctl(self)
	end

	local Encoder = ffi.metatype("OpusEncoder", Encoder)
	local test = Encoder()
]=]
pending[=[
	local ffi = require("ffi")
	ffi.cdef[[
	struct OpusEncoder { int dummy; };
	struct OpusEncoder *opus_encoder_create();
	int opus_encode(struct OpusEncoder *st);
	]]
	local Encoder = {}
	Encoder.__index = Encoder

	function Encoder:__new()
		return assert(ffi.C.opus_encoder_create())
	end

	function Encoder:encode()
		--attest.equal(assert(self.dummy), _ as number)
		print(self)
		return ffi.C.opus_encode(self)
	end

	local Encoder = ffi.metatype("OpusEncoder", Encoder)

]=]
analyze[[
    local ffi = require("ffi")

    do
        local C

        -- make sure C is not C | nil because it's assigned to the same value in both branches

        if ffi.os == "Windows" then
            C = assert(ffi.load("ws2_32"))
        else
            C = ffi.C
        end
        
        do 
            attest.equal(C, _ as ffi.C)
        end
    end
]]
analyze[=[
    local ffi = require("ffi")

    if math.random() > 0.5 then
        ffi.cdef[[
            uint32_t FormatMessageA(
                uint32_t dwFlags,
            );
        ]]
        
        do
            if math.random() > 0.5 then
                ffi.C.FormatMessageA(1)
            end
        end
    
        if math.random() > 0.5 then
            ffi.C.FormatMessageA(1)
        end
    end
]=]
analyze[=[
    local ffi = require("ffi")

    local x: boolean
    if x == true then
        error("LOL")
    end
    
    attest.equal(x, false)
    
    ffi.cdef[[
        void strerror(int errnum);
    ]]
    
    if ffi.os == "Windows" then
        local x = ffi.C.strerror
        attest.equal(x, _ as function=(number | TCData<|number|>)>())
    end
]=]
analyze[=[
	ffi.cdef[[void FormatMessageA(void*);]]
	local a = ffi.C.FormatMessageA
	ffi.cdef[[int GetLastError();]]
	attest.equal(ffi.C.FormatMessageA, a)
]=]
analyze[[
	local function foo(x: ffi.typeof_arg("void*")) end
	local y = _ as TCData<|{["s_addr"] = number}|>
	foo(y)
]]
analyze[=[
	ffi.cdef([[
	struct wwww {
		int ai_flags;
		int ai_family;
	};
	]])
	local res = ffi.new("struct wwww[1]", {{ai_flags = 0}})
	attest.equal(res[0].ai_flags, _ as 0)
	attest.equal(res[0].ai_family, _ as number)
]=]
analyze[=[
	local stat_struct
	local OSX = ffi.os == "OSX"
	local X64 = ffi.arch == "x64"

	if OSX then
		stat_struct = ffi.typeof([[
				struct {
					uint32_t st_dev;
					uint16_t st_mode;
				}
			]])
	else
		if X64 then
			stat_struct = ffi.typeof([[
					struct {
						uint64_t st_dev;
						uint64_t st_ino;
					}
				]])
		else
			stat_struct = ffi.typeof([[
					struct {
						uint64_t st_dev;
						uint32_t __st_ino;
					}
				]])
		end
	end

	local statbox = ffi.typeof("$[1]", stat_struct)
	local buff = statbox()
	local s = assert(buff[0])
	attest.equal(s.st_dev, _ as number)

]=]
