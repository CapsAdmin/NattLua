--ANALYZE
local ffi = require("ffi")
local dl = {}
--[[#local type HANDLE = {"c_handle"}]]

do
	do -- error
		if ffi.os == "Windows" then
			ffi.cdef("unsigned long GetLastError(void);")
			ffi.cdef(
				"uint32_t FormatMessageA(uint32_t dwFlags, const void* lpSource, uint32_t dwMessageId, uint32_t dwLanguageId, char* lpBuffer, uint32_t nSize, ...);"
			)

			function dl.reset_error() end

			function dl.last_error()--[[#: string]]
				local error_str = ffi.new("uint8_t[?]", 1024)
				local FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
				local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
				local error_flags = bit.bor(FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS)
				local code = ffi.C.GetLastError()
				local numout = ffi.C.FormatMessageA(error_flags, nil, code, 0, error_str, 1023, nil)

				if numout ~= 0 then
					local err = ffi.string(error_str, numout)

					if err:sub(-2) == "\r\n" then return err:sub(0, -3) end
				end

				return "no error"
			end
		else
			ffi.cdef("char* dlerror(void);")

			function dl.reset_error()
				ffi.C.dlerror()
			end

			function dl.last_error()--[[#: string]]
				local err = ffi.C.dlerror()

				if err == nil then return "null error" end

				return ffi.string(err)
			end
		end
	end

	do -- load
		if ffi.os == "Windows" then
			ffi.cdef("void* LoadLibraryA(const char* file_name);")

			function dl.load(name--[[#: string]], global--[[#: boolean | nil]], lmid--[[#: number | nil]])--[[#: HANDLE | nil]]
				return ffi.C.LoadLibraryA(name)
			end
		else
			ffi.cdef("void* dlopen(const char* file_name, int flags);")
			ffi.cdef("void* dlmopen(long lmid, const char* file_name, int flags);")
			local RTLD_LOCAL = 0x00000
			local RTLD_LAZY = 0x00001
			local RTLD_GLOBAL = 0x00100

			function dl.load(name--[[#: string]], global--[[#: boolean | nil]], lmid--[[#: number | nil]])--[[#: HANDLE | nil]]
				local flags = RTLD_LAZY + (global and RTLD_GLOBAL or RTLD_LOCAL)

				if lmid ~= nil then
					return ffi.C.dlmopen(lmid, name, flags)
				else
					return ffi.C.dlopen(name, flags)
				end
			end
		end
	end

	do -- find symbol
		if ffi.os == "Windows" then
			ffi.cdef("void* GetProcAddress(void* handle, const char* process_name);")

			function dl.find_symbol(handle--[[#: HANDLE]], name--[[#: string]])
				return ffi.C.GetProcAddress(handle, name)--[[# as FFIPointer<|any|>]]
			end
		else
			ffi.cdef("void* dlsym(void* handle, const char* symbol);")
			ffi.cdef("void* dlvsym(void* handle, const char* symbol, const char *version);")

			function dl.find_symbol(handle--[[#: HANDLE]], name--[[#: string]], version--[[#: string | nil]])
				if version ~= nil then
					return ffi.C.dlvsym(handle, name, version)--[[# as FFIPointer<|any|>]]
				end

				return ffi.C.dlsym(handle, name)--[[# as FFIPointer<|any|>]]
			end
		end
	end

	do -- close
		if ffi.os == "Windows" then
			ffi.cdef("int FreeLibrary(void* handle);")

			function dl.free(handle--[[#: HANDLE]])
				return ffi.C.FreeLibrary(handle)
			end
		else
			ffi.cdef("int dlclose(void* handle);")

			function dl.free(handle--[[#: HANDLE]])
				return ffi.C.dlclose(handle)
			end
		end
	end

	do -- iterate phdr (Linux-specific)
		if ffi.os == "Windows" then
			function dl.iterate_phdr()
				error("NYI")
			end
		else
			local phdr

			if ffi.arch == "x64" then
				phdr = ffi.typeof([[struct {
					uint32_t p_type;
					uint32_t p_flags;
					uint64_t p_offset;
					uint64_t p_vaddr;
					uint64_t p_paddr;
					uint64_t p_filesz;
					uint64_t p_memsz;
					uint64_t p_align;
				}]])
			else
				phdr = ffi.typeof([[struct {
					uint32_t p_type;
					uint32_t p_offset;
					uint32_t p_vaddr;
					uint32_t p_paddr;
					uint32_t p_filesz;
					uint32_t p_memsz;
					uint32_t p_flags;
					uint32_t p_align;
				}]])
			end

			local phdr_info = ffi.typeof(
				[[struct {
					$ dlpi_addr;
					const char *dlpi_name;
					const $ *dlpi_phdr;
					uint16_t dlpi_phnum;
				}]],
				ffi.typeof(ffi.arch == "x64" and "uint64_t" or "uint32_t"),
				phdr
			)
			local phdr_callback = ffi.typeof([[int (*)($ *info, size_t size, void *data)]], phdr_info)
			ffi.cdef([[int dl_iterate_phdr($ callback, void *data)]], phdr_callback)

			function dl.iterate_phdr(callback--[[#: phdr_callback[number] ]])
				local out = {}
				local c_callback = ffi.cast(phdr_callback, function(info, size, userdata)
					local phdr_info = {
						addr = info.dlpi_addr,
						name = info.dlpi_name ~= nil and ffi.string(info.dlpi_name) or nil,
					}
					return callback(phdr_info) or 0
				end)
				local result = ffi.C.dl_iterate_phdr(c_callback, nil) --
				(c_callback--[[# as any]]):free()
				return out
			end
		end
	end

	do -- dladdr
		if ffi.os == "Windows" then
			ffi.cdef("int GetModuleFileNameA(void* handle, char* buffer, int size);")

			function dl.address_info(address--[[#: FFIPointer<|number|>]])
				local buffer = ffi.new("char[?]", 1024)
				local size = ffi.C.GetModuleFileNameA(address, buffer, 1023)

				if size == 0 then return nil end

				return {
					name = ffi.string(buffer, size),
					base_address = address,
				}
			end
		else
			local DL_Info = ffi.typeof([[struct {
				const char *dli_fname; // File name of the shared object
				void *dli_fbase;       // Base address of the shared object
				const char *dli_sname; // Name of the symbol closest to addr
				void *dli_saddr;       // Address of the symbol closest to addr
			}]])
			ffi.cdef("int dladdr1(const void *addr, $ *info, void **extra_data, int flags);", DL_Info)

			function dl.address_info(address--[[#: FFIPointer<|number|>]])
				local info = ffi.typeof("$[1]", DL_Info)()
				local result = ffi.C.dladdr1(address, info, nil, 0)

				if result == 0 then return nil end

				return {
					name = ffi.string(info[0].dli_fname),
					base_address = info[0].dli_fbase,
				}
			end
		end
	end

	do -- dlinfo
		if ffi.os == "Windows" then
			function dl.info(handle)
				error("NYI")
			end

			function dl.get_path(handle)
				error("NYI")
			end
		else
			ffi.cdef("int dlinfo(void * handle, int request, void * info);")
			local link_map = ffi.typeof([[struct {
				uint64_t l_addr;
				char *l_name;
				uint64_t *l_ld;
				void *l_next, *l_prev;
			}]])
			local Dl_serpath = ffi.typeof([[struct {
				char *dls_name;
				unsigned int dls_flags;
			}]])
			local Dl_serinfo = ffi.typeof(
				[[struct {
				size_t dls_size;
				unsigned int dls_cnt;
				$ dls_serpath[1]; // Variable length array
				
			}]],
				Dl_serpath
			)
			local ProgramHeaderStruct

			if ffi.arch == "x64" then
				ProgramHeaderStruct = ffi.typeof([[struct {
					uint32_t p_type;
					uint32_t p_flags;
					uint64_t p_offset;
					uint64_t p_vaddr;
					uint64_t p_paddr;
					uint64_t p_filesz;
					uint64_t p_memsz;
					uint64_t p_align;
				}]])
			else
				ProgramHeaderStruct = ffi.typeof([[struct {
					uint32_t p_type;
					uint32_t p_offset;
					uint32_t p_vaddr;
					uint32_t p_paddr;
					uint32_t p_filesz;
					uint32_t p_memsz;
					uint32_t p_flags;
					uint32_t p_align;
				}]])
			end

			local function get_linkmap(handle--[[#: HANDLE]])
				local RTLD_DI_LINKMAP = 2
				local link_map_ptr = ffi.typeof("$ *[1]", link_map)()
				local result = ffi.C.dlinfo(handle, RTLD_DI_LINKMAP, link_map_ptr)

				if result ~= 0 or link_map_ptr[0] == nil then return nil end

				local lmap = link_map_ptr[0]

				if lmap == nil then return nil end

				return {
					base_address = lmap.l_addr,
					name = lmap.l_name ~= nil and ffi.string(lmap.l_name) or "",
					dynamic_section = lmap.l_ld,
				}
			end

			local function get_origin(handle--[[#: HANDLE]])
				local RTLD_DI_ORIGIN = 6
				local origin_buf = ffi.new("char[?]", 4096)
				local result = ffi.C.dlinfo(handle, RTLD_DI_ORIGIN, origin_buf)

				if result ~= 0 then return nil end

				return ffi.string(origin_buf)
			end

			local function get_lmid(handle--[[#: HANDLE]])
				local RTLD_DI_LMID = 1
				local lmid = ffi.new("long[1]")
				local result = ffi.C.dlinfo(handle, RTLD_DI_LMID, lmid)

				if result ~= 0 then return nil end

				return tonumber(lmid[0])
			end

			local function get_search_paths(handle--[[#: HANDLE]])
				local RTLD_DI_SERINFOSIZE = 5
				local RTLD_DI_SERINFO = 4
				local serinfo_size = Dl_serinfo()
				local result = ffi.C.dlinfo(handle, RTLD_DI_SERINFOSIZE, serinfo_size)

				if result ~= 0 or serinfo_size.dls_size == 0 then return nil end

				-- Allocate buffer with correct size
				local serinfo_buf = ffi.new("char[?]", serinfo_size.dls_size)
				local serinfo = ffi.cast(ffi.typeof("$*", Dl_serinfo), serinfo_buf)
				-- Initialize size and count fields
				result = ffi.C.dlinfo(handle, RTLD_DI_SERINFOSIZE, serinfo)

				if result ~= 0 then return nil end

				-- Get the actual search paths
				result = ffi.C.dlinfo(handle, RTLD_DI_SERINFO, serinfo)

				if result ~= 0 then return nil end

				local paths = {}

				for i = 0, serinfo.dls_cnt - 1 do
					local path_entry = (serinfo.dls_serpath--[[# as any]])[i]--[[# as Dl_serpath]]

					if path_entry.dls_name ~= nil then
						table.insert(
							paths,
							{
								name = ffi.string(path_entry.dls_name),
								flags = path_entry.dls_flags,
							}
						)
					end
				end

				return paths
			end

			local function get_tls(handle--[[#: HANDLE]])
				local RTLD_DI_TLS_MODID = 9
				local tls_modid = ffi.new("size_t[1]")
				local result = ffi.C.dlinfo(handle, RTLD_DI_TLS_MODID, tls_modid)

				if result ~= 0 then return nil end

				local RTLD_DI_TLS_DATA = 10
				local tls_data = ffi.new("void*[1]")
				local result = ffi.C.dlinfo(handle, RTLD_DI_TLS_DATA, tls_data)

				if result ~= 0 or tls_data[0] == nil then return nil end

				return {
					modid = tonumber(tls_modid[0]),
					data = tls_data[0],
				}
			end

			-- Since glibc 2.34.1
			local function get_phdr(handle--[[#: HANDLE]])
				local RTLD_DI_PHDR = 11
				local phdr_ptr = ffi.typeof("$*[1]", ProgramHeaderStruct)()
				local result = ffi.C.dlinfo(handle, RTLD_DI_PHDR, phdr_ptr)

				if result <= 0 or phdr_ptr[0] == nil then return nil end

				-- Convert program header types to readable names
				local pt_types = {
					[0] = "PT_NULL",
					[1] = "PT_LOAD",
					[2] = "PT_DYNAMIC",
					[3] = "PT_INTERP",
					[4] = "PT_NOTE",
					[5] = "PT_SHLIB",
					[6] = "PT_PHDR",
					[7] = "PT_TLS",
					[0x60000000] = "PT_LOOS",
					[0x6fffffff] = "PT_HIOS",
					[0x70000000] = "PT_LOPROC",
					[0x7fffffff] = "PT_HIPROC",
					[0x6474e550] = "PT_GNU_EH_FRAME",
					[0x6474e550] = "PT_SUNW_EH_FRAME",
					[0x6464e550] = "PT_SUNW_UNWIND",
					[0x6474e551] = "PT_GNU_STACK",
					[0x6474e552] = "PT_GNU_RELRO",
					[0x6474e553] = "PT_GNU_PROPERTY",
					[0x65a3dbe5] = "PT_OPENBSD_MUTABLE",
					[0x65a3dbe6] = "PT_OPENBSD_RANDOMIZE",
					[0x65a3dbe7] = "PT_OPENBSD_WXNEEDED",
					[0x65a3dbe8] = "PT_OPENBSD_NOBTCFI",
					[0x65a3dbe9] = "PT_OPENBSD_SYSCALLS",
					[0x65a41be6] = "PT_OPENBSD_BOOTDATA",
					[0x70000000] = "PT_ARM_ARCHEXT",
					[0x70000001] = "PT_ARM_EXIDX",
					[0x70000001] = "PT_ARM_UNWIND",
					[0x70000002] = "PT_AARCH64_MEMTAG_MTE",
					[0x70000000] = "PT_MIPS_REGINFO",
					[0x70000001] = "PT_MIPS_RTPROC",
					[0x70000002] = "PT_MIPS_OPTIONS",
					[0x70000003] = "PT_MIPS_ABIFLAGS",
					[0x70000003] = "PT_RISCV_ATTRIBUTES",
				}

				-- Convert program header flags to readable format
				local function decode_flags(flags)
					local map = {}

					if bit.band(flags, 0x1) ~= 0 then map.execute = true end

					if bit.band(flags, 0x2) ~= 0 then map.write = true end

					if bit.band(flags, 0x4) ~= 0 then map.read = true end

					return map
				end

				local headers = {}
				local phdr_array = phdr_ptr[0]

				for i = 0, result - 1 do
					local phdr = assert(phdr_array[i])
					table.insert(
						headers,
						{
							type = pt_types[phdr.p_type] or string.format("0x%x", phdr.p_type),
							flags = decode_flags(phdr.p_flags),
							offset = tonumber(phdr.p_offset),
							virtual_addr = tonumber(phdr.p_vaddr),
							physical_addr = tonumber(phdr.p_paddr),
							file_size = tonumber(phdr.p_filesz),
							memory_size = tonumber(phdr.p_memsz),
							alignment = tonumber(phdr.p_align),
						}
					)
				end

				return headers
			end

			function dl.get_path(handle--[[#: HANDLE]])
				return get_origin(handle)
			end

			function dl.info(handle--[[#: HANDLE]])
				local info = {}
				info.linkmap = get_linkmap(handle)
				info.origin = get_origin(handle)
				info.lmid = get_lmid(handle)
				info.search_paths = get_search_paths(handle)
				info.tls = get_tls(handle)
				info.program_headers = get_phdr(handle)
				return info
			end
		end
	end
end

local xffi = {}
xffi.dl = dl

do -- ffi.load
	local function ends_with(a--[[#: string]], b--[[#: string]])
		return a:sub(-#b) == b
	end

	local ext_map = {
		OSX = ".dylib",
		Windows = ".dll",
		Linux = ".so",
		BSD = ".so",
	}

	local function fix_path(name--[[#: string]])
		if name:find("/", 0, true) or (ffi.os == "Windows" and name:find("\\", nil, true)) then
			return name
		end

		local ext = ext_map[ffi.os]

		if not ends_with(name, ext) then name = name .. ext end

		if ffi.os ~= "Windows" then
			if name:sub(1, 3) ~= "lib" then name = "lib" .. name end
		end

		return name
	end

	local function find_real_path_from_ld_script(err--[[#: string]])
		local name = err:match("^(.-):")

		if not name then return nil end

		local file = io.open(name, "r")

		if not file then return nil end

		local header = "/* GNU ld script"
		local path

		if file:read(#header) == header then
			for line in file:lines() do
				path = line:match("GROUP %( (.-) ") or line:match("INPUT %( (.-) ")

				if path then break end
			end
		end

		file:close()
		return path
	end

	function xffi.load(name--[[#: string]], global--[[#: boolean | nil]])
		name = fix_path(name)
		dl.reset_error()
		local handle = dl.load(name, global)

		if handle == nil then
			local err = dl.last_error()

			if ffi.os == "Linux" then
				local path = find_real_path_from_ld_script(err)

				if path then return xffi.load(path, global) end
			end

			return nil, string.format("cannot load library '%s': error %s", name, err)
		end

		return handle
	end
end

function xffi.find_symbol(handle, name)
	return dl.find_symbol(handle, name)
end

function xffi.unload(handle)
	dl.reset_error()

	if dl.free(handle) ~= 0 then return false, dl.last_error() end

	return true
end

function xffi.load_table(path--[[#: string]], tbl--[[#: ref Map<|string, any|>]])
	local lib = assert(xffi.load(path))
	local abs_path = dl.get_path(lib)
	local out = {}

	for name, ctype in pairs(tbl) do
		local func_ptr = xffi.find_symbol(lib, name)

		if func_ptr == nil then
			print("cannot find symbol " .. name .. " in " .. abs_path)
		end

		out[name] = ffi.cast(ctype, func_ptr)
	end

	return out
end

do -- TEST
	local ffi = require("ffi")
	local timespec = ffi.typeof("struct {long int tv_sec; long tv_nsec; }")
	local funcs = xffi.load_table(
		"c",
		{
			printf = ffi.typeof("int (*)(const char *format, ...)"),
			clock_gettime = ffi.typeof("int (*)(int clock_id, $ *tp)", timespec),
		}
	)
	funcs.printf("hello\n")

	local function time()
		local ts = timespec()
		funcs.clock_gettime(1, ts)
		return tonumber(ts.tv_sec) + tonumber(ts.tv_nsec) * 0.000000001
	end

	print(time())
end

return xffi
