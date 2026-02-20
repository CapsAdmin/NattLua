local bit_band = bit.band
local fs = {}

if not jit then

elseif jit.arch ~= "Windows" then
	local ffi = require("ffi")

	do
		ffi.cdef("char *strerror(int);")

		function fs.last_error()
			local num = ffi.errno()
			local err = ffi.string(ffi.C.strerror(num))
			return err == "" and tostring(num) or err
		end
	end

	do -- attributes
		local stat_struct

		if jit.os == "OSX" then
			stat_struct = ffi.typeof([[
            struct {
                uint32_t st_dev;
                uint16_t st_mode;
                uint16_t st_nlink;
                uint64_t st_ino;
                uint32_t st_uid;
                uint32_t st_gid;
                uint32_t st_rdev;
                size_t st_atime;
                long st_atime_nsec;
                size_t st_mtime;
                long st_mtime_nsec;
                size_t st_ctime;
                long st_ctime_nsec;
                size_t st_btime; 
                long st_btime_nsec;
                int64_t st_size;
                int64_t st_blocks;
                int32_t st_blksize;
                uint32_t st_flags;
                uint32_t st_gen;
                int32_t st_lspare;
                int64_t st_qspare[2];
            }
        ]])
		else
			if jit.arch == "x64" then
				stat_struct = ffi.typeof([[
                struct {
                    uint64_t st_dev;
                    uint64_t st_ino;
                    uint64_t st_nlink;
                    uint32_t st_mode;
                    uint32_t st_uid;
                    uint32_t st_gid;
                    uint32_t __pad0;
                    uint64_t st_rdev;
                    int64_t st_size;
                    int64_t st_blksize;
                    int64_t st_blocks;
                    uint64_t st_atime;
                    uint64_t st_atime_nsec;
                    uint64_t st_mtime;
                    uint64_t st_mtime_nsec;
                    uint64_t st_ctime;
                    uint64_t st_ctime_nsec;
                    int64_t __unused[3];
                }
            ]])
			else
				stat_struct = ffi.typeof([[
                struct {
                    uint64_t st_dev;
                    uint8_t __pad0[4];
                    uint32_t __st_ino;
                    uint32_t st_mode;
                    uint32_t st_nlink;
                    uint32_t st_uid;
                    uint32_t st_gid;
                    uint64_t st_rdev;
                    uint8_t __pad3[4];
                    int64_t st_size;
                    uint32_t st_blksize;
                    uint64_t st_blocks;
                    uint32_t st_atime;
                    uint32_t st_atime_nsec;
                    uint32_t st_mtime;
                    uint32_t st_mtime_nsec;
                    uint32_t st_ctime;
                    uint32_t st_ctime_nsec;
                    uint64_t st_ino;
                }
            ]])
			end
		end

		local statbox = ffi.typeof("$[1]", stat_struct)
		local stat_func
		local stat_func_link
		local DIRECTORY = 0x4000

		if jit.os == "OSX" then
			ffi.cdef[[int stat64(const char *path, void *buf);]]
			stat_func = ffi.C.stat64
			ffi.cdef[[int lstat64(const char *path, void *buf);]]
			stat_func_link = ffi.C.lstat64
		else
			ffi.cdef("unsigned long syscall(int number, ...);")
			local arch = jit.arch
			stat_func = function(path--[[#: string]], buff--[[#: any]])
				return ffi.C.syscall(arch == "x64" and 4 or 195, path, buff)
			end
			stat_func_link = function(path--[[#: string]], buff--[[#: any]])
				return ffi.C.syscall(arch == "x64" and 6 or 196, path, buff)
			end
		end

		function fs.get_attributes(path, link)
			local buff = statbox()
			local ret = link and stat_func_link(path, buff) or stat_func(path, buff)

			if ret == 0 then
				return {
					last_accessed = tonumber(buff[0].st_atime),
					last_changed = tonumber(buff[0].st_ctime),
					last_modified = tonumber(buff[0].st_mtime),
					type = bit.band(buff[0].st_mode, DIRECTORY) ~= 0 and "directory" or "file",
					size = tonumber(buff[0].st_size),
					mode = buff[0].st_mode,
					links = buff[0].st_nlink,
				}
			end

			return nil, fs.last_error()
		end

		do
			local buff = statbox()

			function fs.get_size(path, link)
				local ret = link and stat_func_link(path, buff) or stat_func(path, buff)

				if ret ~= 0 then return nil, fs.last_error() end

				return tonumber(buff[0].st_size)
			end
		end

		do
			local buff = statbox()

			function fs.get_type(path--[[#: string]])
				if stat_func(path, buff) == 0 then
					return bit_band(buff[0].st_mode, DIRECTORY) ~= 0 and "directory" or "file"
				end

				return nil
			end
		end
	end

	do -- find files
		local dot = string.byte(".")

		local function is_dots(ptr)
			if ptr[0] == dot then
				if ptr[1] == dot and ptr[2] == 0 then return true end

				if ptr[1] == 0 then return true end
			end

			return false
		end

		-- NOTE: 64bit version
		local dirent_struct

		if jit.os == "OSX" then
			if jit.arch == "arm64" then
				dirent_struct = ffi.typeof([[
					struct {
					uint64_t d_ino;
					uint64_t d_seekoff;
					uint16_t d_reclen;
					uint16_t d_namlen;
					uint8_t d_type;
					char d_name[1024];
					}
				]])
				ffi.cdef([[$ *readdir(void *dirp);]], dirent_struct)
			else
				dirent_struct = ffi.typeof([[
					struct {
						uint64_t d_ino;
						uint64_t d_seekoff;
						uint16_t d_reclen;
						uint16_t d_namlen;
						uint8_t d_type;
						char d_name[1024];
					}
				]])
				ffi.cdef([[$ *readdir(void *dirp) asm("readdir$INODE64");]], dirent_struct)
			end
		else
			dirent_struct = ffi.typeof([[
				struct {
					uint64_t d_ino;
					int64_t d_off;
					unsigned short d_reclen;
					unsigned char d_type;
					char d_name[256];
				}
			]])
			ffi.cdef([[$ *readdir(void *dirp) asm("readdir64");]], dirent_struct)
		end

		ffi.cdef[[void *opendir(const char *name);]]
		ffi.cdef[[int closedir(void *dirp);]]

		function fs.get_files(path)
			local out = {}
			local ptr = ffi.C.opendir(path or "")

			if ptr == nil then return nil, fs.last_error() end

			local i = 1

			while true do
				local dir_info = ffi.C.readdir(ptr)

				if dir_info == nil then break end

				if not is_dots(dir_info.d_name) then
					out[i] = ffi.string(dir_info.d_name)
					i = i + 1
				end
			end

			ffi.C.closedir(ptr)
			return out
		end

		function fs.walk(path, tbl, errors, can_traverse, files_only)
			local ptr = ffi.C.opendir(path or "")

			if ptr == nil then
				table.insert(errors, {path = path, error = fs.last_error()})
				return
			end

			if not files_only then
				tbl[tbl[0]] = path
				tbl[0] = tbl[0] + 1
			end

			while true do
				local dir_info = ffi.C.readdir(ptr)

				if dir_info == nil then break end

				if not is_dots(dir_info.d_name) then
					local name = path .. ffi.string(dir_info.d_name)

					if dir_info.d_type == 4 then
						if not can_traverse or can_traverse(name) ~= false then
							fs.walk(name .. "/", tbl, errors, can_traverse, files_only)
						end
					else
						tbl[tbl[0]] = name
						tbl[0] = tbl[0] + 1
					end
				end
			end

			ffi.C.closedir(ptr)
			return tbl
		end
	end

	do
		ffi.cdef("int mkdir(const char *filename, uint32_t mode);")

		function fs.create_directory(path)
			if ffi.C.mkdir(path, 448) ~= 0 then return nil, fs.last_error() end

			return true
		end
	end

	do
		ffi.cdef("int remove(const char *pathname);")

		function fs.remove_file(path)
			if ffi.C.remove(path) ~= 0 then return nil, fs.last_error() end

			return true
		end
	end

	do
		ffi.cdef("int rmdir(const char *filename);")

		function fs.remove_directory(path)
			if ffi.C.rmdir(path) ~= 0 then return nil, fs.last_error() end

			return true
		end
	end

	do
		ffi.cdef("int chdir(const char *filename);")

		function fs.set_current_directory(path)
			if ffi.C.chdir(path) ~= 0 then return nil, fs.last_error() end

			return true
		end
	end

	do
		ffi.cdef("char *getcwd(char *buf, size_t size);")

		function fs.get_current_directory()
			local temp = ffi.new("char[1024]")
			return ffi.string(ffi.C.getcwd(temp, ffi.sizeof(temp)))
		end
	end
else
	local ffi = require("ffi")

	do
		local ffi = require("ffi")
		ffi.cdef("uint32_t GetLastError();")
		ffi.cdef[[
			uint32_t FormatMessageA(
				uint32_t dwFlags,
				const void* lpSource,
				uint32_t dwMessageId,
				uint32_t dwLanguageId,
				char* lpBuffer,
				uint32_t nSize,
				va_list *Arguments
			);
		]]
		local error_str = ffi.new("uint8_t[?]", 1024)
		local FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
		local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
		local error_flags = bit.bor(FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS)

		function fs.last_error()
			local code = ffi.C.GetLastError()
			local numout = ffi.C.FormatMessageA(error_flags, nil, code, 0, error_str, 1023, nil)
			local err = numout ~= 0 and ffi.string(error_str, numout)

			if err and err:sub(-2) == "\r\n" then return err:sub(0, -3) end

			return err
		end
	end

	local DIRECTORY = 0x10
	local time_struct = ffi.typeof([[
		struct {
			unsigned long high;
			unsigned long low;
		}
	]])

	do
		local time_type = ffi.typeof("uint64_t *")
		local tonumber = tonumber
		local POSIX_TIME = function(ptr)
			return tonumber(ffi.cast(time_type, ptr)[0] / 10000000 - 11644473600)
		end
		local file_attributes = ffi.typeof(
			[[
			struct {
				unsigned long dwFileAttributes;
				$ ftCreationTime;
				$ ftLastAccessTime;
				$ ftLastWriteTime;
				unsigned long nFileSizeHigh;
				unsigned long nFileSizeLow;
			}
		]],
			time_struct,
			time_struct,
			time_struct
		)
		ffi.cdef([[int GetFileAttributesExA(const char *, int, $ *);]], file_attributes)
		local info_box = ffi.typeof("$[1]", file_attributes)

		function fs.get_attributes(path)
			local info = info_box()

			if ffi.C.GetFileAttributesExA(path, 0, info) == 0 then
				return nil, fs.last_error()
			end

			return {
				raw_info = info[0],
				creation_time = POSIX_TIME(info[0].ftCreationTime),
				last_accessed = POSIX_TIME(info[0].ftLastAccessTime),
				last_modified = POSIX_TIME(info[0].ftLastWriteTime),
				last_changed = -1, -- last permission changes
				size = info[0].nFileSizeLow,
				type = bit.band(info[0].dwFileAttributes, DIRECTORY) == DIRECTORY and
					"directory" or
					"file",
			}
		end

		do
			local info = info_box()

			function fs.get_type(path)
				if ffi.C.GetFileAttributesExA(path, 0, info) == 0 then return nil end

				return bit.band(info[0].dwFileAttributes, DIRECTORY) == DIRECTORY and
					"directory" or
					"file"
			end
		end
	end

	do
		local find_data_struct = ffi.typeof(
			[[
			struct {
				unsigned long dwFileAttributes;

				$ ftCreationTime;
				$ ftLastAccessTime;
				$ ftLastWriteTime;

				unsigned long nFileSizeHigh;
				unsigned long nFileSizeLow;

				unsigned long dwReserved0;
				unsigned long dwReserved1;

				char cFileName[260];
				char cAlternateFileName[14];
			}
		]],
			time_struct,
			time_struct,
			time_struct
		)
		ffi.cdef([[int FindNextFileA(void *, $ *);]], find_data_struct)
		ffi.cdef([[void *FindFirstFileA(const char *, $ *);]], find_data_struct)
		ffi.cdef[[int FindClose(void *);]]
		local dot = string.byte(".")

		local function is_dots(ptr)
			if ptr[0] == dot then
				if ptr[1] == dot and ptr[2] == 0 then return true end

				if ptr[1] == 0 then return true end
			end

			return false
		end

		local ffi_cast = ffi.cast
		local ffi_string = ffi.string
		local INVALID_FILE = ffi.cast("void *", -1)
		local data_box = ffi.typeof("$[1]", find_data_struct)
		local data = data_box()

		function fs.get_files(dir)
			if path == "" then path = "." end

			if dir:sub(-1) ~= "/" then dir = dir .. "/" end

			local handle = ffi.C.FindFirstFileA(dir .. "*", data)

			if handle == nil then return nil, fs.last_error() end

			local out = {}

			if handle ~= INVALID_FILE then
				local i = 1

				repeat
					if not is_dots(data[0].cFileName) then
						out[i] = ffi_string(data[0].cFileName)
						i = i + 1
					end				
				until ffi.C.FindNextFileA(handle, data) == 0

				if ffi.C.FindClose(handle) == 0 then return nil, fs.last_error() end
			end

			return out
		end

		function fs.walk(path, tbl, errors, can_traverse, files_only)
			local handle = ffi.C.FindFirstFileA(path .. "*", data)

			if handle == nil then
				list.insert(errors, {path = path, error = fs.last_error()})
				return
			end

			if not files_only then
				tbl[tbl[0]] = path
				tbl[0] = tbl[0] + 1
			end

			if handle ~= INVALID_FILE then
				local i = 1

				repeat
					if not is_dots(data[0].cFileName) then
						local name = path .. ffi_string(data[0].cFileName)

						if bit.band(data[0].dwFileAttributes, DIRECTORY) == DIRECTORY then
							if not can_traverse or can_traverse(name) ~= false then
								fs.walk(name .. "/", tbl, errors)
							end
						else
							tbl[tbl[0]] = name
							tbl[0] = tbl[0] + 1
						end
					end				
				until ffi.C.FindNextFileA(handle, data) == 0

				if ffi.C.FindClose(handle) == 0 then return nil, fs.last_error() end
			end

			return tbl
		end
	end

	do
		ffi.cdef[[unsigned long GetCurrentDirectoryA(unsigned long, char *);]]

		function fs.get_current_directory()
			local buffer = ffi.new("char[260]")
			local length = ffi.C.GetCurrentDirectoryA(260, buffer)
			return ffi.string(buffer, length):gsub("\\", "/")
		end
	end

	do
		ffi.cdef[[int SetCurrentDirectoryA(const char *);]]

		function fs.set_current_directory(path)
			if ffi.C.SetCurrentDirectoryA(path) == 0 then return nil, fs.last_error() end

			return true
		end
	end

	do
		ffi.cdef[[int CreateDirectoryA(const char *, void *);]]

		function fs.create_directory(path)
			if ffi.C.CreateDirectoryA(path, nil) == 0 then return nil, fs.last_error() end

			return true
		end
	end

	do
		ffi.cdef[[int DeleteFileA(const char *);]]

		function fs.remove_file(path)
			if ffi.C.DeleteFileA(path) == 0 then return nil, fs.last_error() end

			return true
		end
	end

	do
		ffi.cdef[[int RemoveDirectoryA(const char *);]]

		function fs.remove_directory(path)
			if ffi.C.RemoveDirectoryA(path) == 0 then return nil, fs.last_error() end

			return true
		end
	end
end

function fs.is_directory(path--[[#: string]])
	local type = fs.get_type(path)
	return type == "directory"
end

function fs.is_file(path--[[#: string]])
	local type = fs.get_type(path)
	return type == "file"
end

function fs.exists(path--[[#: string]])
	local type = fs.get_type(path)
	return type ~= nil
end

do
	local old = fs.remove_directory

	function fs.remove_directory(path, recursive)
		if not recursive then return old(path) end

		-- For recursive removal, get all files/dirs and remove them
		local files = fs.get_files_recursive(path)

		if files then
			for i = #files, 1, -1 do
				local file_path = files[i]
				local type = fs.get_type(file_path)

				if type == "file" then
					fs.remove_file(file_path)
				elseif type == "directory" then
					old(file_path)
				end
			end
		end

		return fs.remove_directory(path)
	end
end

function fs.read(path)
	local f, err = io.open(path, "rb")

	if not f then return nil, err end

	local content = f:read("*all")

	if content == nil then
		f:close()
		return nil, "file is empty"
	end

	f:close()
	return content
end

function fs.write(path, content)
	local f = io.open(path, "wb")

	if not f then return nil, "Failed to open file for writing" end

	f:write(content)
	f:close()
	return true
end

function fs.iterate(dir, pattern)
	local files = fs.get_files and fs.get_files(dir) or {}
	local i = 0
	local n = #files
	return function()
		i = i + 1

		while i <= n do
			local file = files[i]

			if not pattern or file:match(pattern) then return dir .. "/" .. file end

			i = i + 1
		end
	end
end

function fs.get_parent_directory(path)
	-- Normalize path separators to forward slash
	path = path:gsub("\\", "/")

	-- Remove trailing slash if present
	if path:sub(-1) == "/" and path ~= "/" then path = path:sub(1, -2) end

	-- Extract parent directory
	local parent = path:match("(.+)/[^/]+$")

	-- Handle special cases
	if not parent then
		if path == "/" then
			return nil -- Root has no parent
		else
			return "." -- Current directory is parent
		end
	end

	-- Return the parent directory
	return parent
end

function fs.create_directory_recursive(path)
	-- Handle empty or root path
	if path == "" or path == "/" then return true end

	-- Normalize path separators to forward slash
	path = path:gsub("\\", "/")

	-- Remove trailing slash if present
	if path:sub(-1) == "/" then path = path:sub(1, -2) end

	-- Check if directory already exists
	if fs.exists(path) then
		if fs.is_directory(path) then
			return true -- Already exists as directory
		else
			return nil, "Path exists but is not a directory" -- Path exists as a file
		end
	end

	-- Get parent directory
	local parent = path:match("(.+)/[^/]+$") or ""

	-- If parent directory doesn't exist, create it first
	if parent ~= "" and not fs.exists(parent) then
		local ok, err = fs.create_directory_recursive(parent)

		if not ok then
			return nil, "Failed to create parent directory: " .. (err or "unknown error")
		end
	end

	-- Create the directory
	return fs.create_directory(path)
end

function fs.get_files_recursive(path)
	if path == "" then path = "." end

	if path:sub(-1) ~= "/" then path = path .. "/" end

	local out = {}
	local errors = {}
	out[0] = 1

	if not fs.walk(path, out, errors, nil, true) then
		return nil, errors[1].error
	end

	out[0] = nil
	return out, errors[1] and errors or nil
end

return fs
