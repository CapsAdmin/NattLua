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
IMPORTS['example_project/src/platforms/unix/filesystem.nlua'] = function(...) local OSX = jit.os == "OSX"
local X64 = jit.arch == "x64"

local fs = _G.fs or {}

local ffi = require("ffi")

ffi.cdef([[
	typedef unsigned long ssize_t;
	char *strerror(int);
	void *fopen(const char *filename, const char *mode);
	int open(const char *pathname, int flags, ...);
	size_t fread(void *ptr, size_t size, size_t nmemb, void *stream);
	size_t fwrite(const void *ptr, size_t size, size_t nmemb, void *stream);
	int fseek(void *stream, long offset, int whence);
	long int ftell ( void * stream );
	int fclose(void *fp);
	int close(int fd);
	int feof(void *stream);
	char *getcwd(char *buf, size_t size);
	int chdir(const char *filename);
	int mkdir(const char *filename, uint32_t mode);
	int rmdir(const char *filename);
	int fileno(void *stream);
	int remove(const char *pathname);
	int fchmod(int fd, int mode);

	typedef struct DIR DIR;
	DIR *opendir(const char *name);
	int closedir(DIR *dirp);
	ssize_t syscall(int number, ...);


	ssize_t read(int fd, void *buf, size_t count);

	struct inotify_event
	{
		int wd;
		uint32_t mask;
		uint32_t cookie;
		uint32_t len;
		char * name;
	};
	int inotify_init(void);
	int inotify_init1(int flags);
	int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
	int inotify_rm_watch(int fd, int wd);

	static const uint32_t IN_MODIFY = 0x00000002;
]])

local O_RDONLY    = 0x0000    -- open for reading only
local O_WRONLY    = 0x0001    -- open for writing only
local O_RDWR      = 0x0002    -- open for reading and writing
local O_NONBLOCK  = 0x0004    -- no delay
local O_APPEND    = 0x0008    -- set append mode
local O_SHLOCK    = 0x0010    -- open with shared file lock
local O_EXLOCK    = 0x0020    -- open with exclusive file lock
local O_ASYNC     = 0x0040    -- signal pgrp when data ready
local O_NOFOLLOW  = 0x0100    -- don't follow symlinks
local O_CREAT     = 0x0200    -- create if nonexistant
local O_TRUNC     = 0x0400    -- truncate to zero length
local O_EXCL      = 0x0800    -- error if already exists

local function last_error(num)
	num = num or ffi.errno()
	local err = ffi.string(ffi.C.strerror(num))
	return err == "" and tostring(num) or err
end

fs.open = ffi.C.fopen
fs.read = ffi.C.fread
fs.write = ffi.C.fwrite
fs.seek = ffi.C.fseek
fs.tell = ffi.C.ftell
fs.close = ffi.C.fclose
fs.eof = ffi.C.feof

if OSX then
	ffi.cdef([[
		int stat64(const char *path, void *buf);
		int lstat64(const char *path, void *buf);
		typedef size_t time_t;
		struct dirent {
			uint64_t d_ino;
			uint64_t d_seekoff;
			uint16_t d_reclen;
			uint16_t d_namlen;
			uint8_t  d_type;
			char d_name[1024];
		};
		struct dirent *readdir(DIR *dirp) asm("readdir$INODE64");
	]])
else
	ffi.cdef([[
		struct dirent {
			uint64_t        d_ino;
			int64_t         d_off;
			unsigned short  d_reclen;
			unsigned char   d_type;
			char            d_name[256];
		};
		struct dirent *readdir(DIR *dirp) asm("readdir64");
	]])
end

local stat_struct

if OSX then
	stat_struct = ffi.typeof([[
		struct {
			uint32_t st_dev;
			uint16_t st_mode;
			uint16_t st_nlink;
			uint64_t st_ino;
			uint32_t st_uid;
			uint32_t st_gid;
			uint32_t st_rdev;
			// NOTE: these were `struct timespec`
			time_t   st_atime;
			long     st_atime_nsec;
			time_t   st_mtime;
			long     st_mtime_nsec;
			time_t   st_ctime;
			long     st_ctime_nsec;
			time_t   st_btime; // birth-time i.e. creation time
			long     st_btime_nsec;
			int64_t  st_size;
			int64_t  st_blocks;
			int32_t  st_blksize;
			uint32_t st_flags;
			uint32_t st_gen;
			int32_t  st_lspare;
			int64_t  st_qspare[2];
		}
	]])
else
	if X64 then
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
				int64_t  st_size;
				int64_t  st_blksize;
				int64_t  st_blocks;
				uint64_t st_atime;
				uint64_t st_atime_nsec;
				uint64_t st_mtime;
				uint64_t st_mtime_nsec;
				uint64_t st_ctime;
				uint64_t st_ctime_nsec;
				int64_t  __unused[3];
			}
		]])
	else
		stat_struct = ffi.typeof([[
			struct {
				uint64_t st_dev;
				uint8_t  __pad0[4];
				uint32_t __st_ino;
				uint32_t st_mode;
				uint32_t st_nlink;
				uint32_t st_uid;
				uint32_t st_gid;
				uint64_t st_rdev;
				uint8_t  __pad3[4];
				int64_t  st_size;
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

if OSX then
	stat_func = ffi.C.stat64
	stat_func_link = ffi.C.lstat64
else
	stat_func = function(path, buff)
		return ffi.C.syscall(X64 and 4 or 195, path, buff)
	end

	stat_func_link = function(path, buff)
		return ffi.C.syscall(X64 and 6 or 196, path, buff)
	end
end

ffi.cdef([[
	int setxattr(const char *path, const char *name, const char *value, size_t size, int flags);
	ssize_t getxattr(const char *path, const char *name, const char *value, size_t size);
]])

function fs.setcustomattribute(path, data)
	if ffi.C.setxattr(path, "goluwa_attributes", data, #data, 0x2) ~= 0 then
		return nil, last_error()
	end
	return true
end

function fs.getcustomattribute(path)
	local size = ffi.C.getxattr(path, "goluwa_attributes", nil, 0)
	if size == -1 then
		return nil, last_error()
	end

	local buffer = ffi.string("char[?]", size)
	ffi.C.getxattr(path, "goluwa_attributes", buffer, size)

	return ffi.string(buffer)
end

if not OSX then
	local flags = {
		access = 0x00000001, -- File was accessed
		modify = 0x00000002, -- File was modified
		attrib = 0x00000004, -- Metadata changed
		close_write = 0x00000008, -- Writtable file was closed
		close_nowrite = 0x00000010, -- Unwrittable file closed
		open = 0x00000020, -- File was opened
		moved_from = 0x00000040, -- File was moved from X
		moved_to = 0x00000080, -- File was moved to Y
		create = 0x00000100, -- Subfile was created
		delete = 0x00000200, -- Subfile was deleted
		delete_self = 0x00000400, -- Self was deleted
		move_self = 0x00000800, -- Self was moved
		unmount = 0x00002000, -- Backing fs was unmounted
		q_overflow = 0x00004000, -- Event queued overflowed
		ignored = 0x00008000, -- File was ignored
		onlydir = 0x01000000, -- only watch the path if it is a directory
		dont_follow = 0x02000000, -- don't follow a sym link
		excl_unlink = 0x04000000, -- exclude events on unlinked objects
		mask_create = 0x10000000, -- only create watches
		mask_add = 0x20000000, -- add to the mask of an already existing watch
		isdir = 0x40000000, -- event occurred against dir
		oneshot = 0x80000000, -- only send event once
	}
	local IN_NONBLOCK = 2048

	local fd = ffi.C.inotify_init1(IN_NONBLOCK)
	local max_length = 8192
	local length = ffi.sizeof("struct inotify_event")
	local buffer = ffi.new("char[?]", max_length)
	local queue = {}



	local function TableToFlags(flags, valid_flags, operation)
		if type(flags) == "string" then
			flags = {flags}
		end

		local out = 0

		for k, v in pairs(flags) do
			local flag = valid_flags[v] or valid_flags[k]
			if not flag then
				error("invalid flag", 2)
			end
			if type(operation) == "function" then
				local num = tonumber(flag)
				if not num then
					error("cannot convert flag " .. flag .. " to number")
					return
				end

				-- TODO
				if operation then
					out = operation(out, num)
				end
			else
				out = bit.band(out, tonumber(flag))
			end
		end

		return out
	end


	local function FlagsToTable(flags, valid_flags)

		if not flags then return valid_flags.default_valid_flag end

		local out = {}

		for k, v in pairs(valid_flags) do
			if bit.band(flags, v) > 0 then
				out[k] = true
			end
		end

		return out
	end


	function fs.watch(path, mask)
		local wd = ffi.C.inotify_add_watch(fd, path, mask and TableToFlags(mask, flags) or 4095)
		queue[wd] = {}

		local self = {}
		function self:Read()
			local len = ffi.C.read(fd, buffer, length)
			if len >= length then
				local res = ffi.cast("struct inotify_event*", buffer)
				table.insert(queue[res.wd], {
					cookie = res.cookie,
					name = ffi.string(res.name, res.len),
					flags = FlagsToTable(res.mask, flags),
				})
			end

			if queue[wd] and queue[wd][1] then
				return table.remove(queue[wd])
			end
		end

		function self:Remove()
			ffi.C.inotify_rm_watch(fd, wd)
			queue[wd] = nil
		end

		return self
	end
end

do
	do
		local dot = string.byte(".")
		local function is_dots(ptr)
			if ptr[0] == dot then
				if ptr[1] == dot and ptr[2] == 0 then
					return true
				end
				if ptr[1] == 0 then
					return true
				end
			end

			return false
		end

		local ffi_string = ffi.string
		local opendir = ffi.C.opendir
		local readdir = ffi.C.readdir
		local closedir = ffi.C.closedir

		function fs.get_files(path)
			local out = {}

			local ptr = opendir(path or "")

			if ptr == nil then
				return nil, last_error()
			end

			local i = 1
			while true do
				local dir_info = readdir(ptr)

				if dir_info == nil then break end

				if not is_dots(dir_info.d_name) then
					out[i] = ffi_string(dir_info.d_name)
					i = i + 1
				end
			end

			closedir(ptr)

			return out
		end

		local function walk(path, tbl, errors, can_traverse)
			local ptr = opendir(path or "")

			if ptr == nil then
				table.insert(errors, {path = path, error = last_error()})
				return
			end

			tbl[tbl[0]] = path
			tbl[0] = tbl[0] + 1

			while true do
				local dir_info = readdir(ptr)

				if dir_info == nil then break end

				if not is_dots(dir_info.d_name) then
					local name = path .. ffi_string(dir_info.d_name)

					if dir_info.d_type == 4 then
						local name = name .. "/"
						if not can_traverse or can_traverse(name) ~= false then
							walk(name, tbl, errors, can_traverse)
						end
					else
						tbl[tbl[0]] = name
						tbl[0] = tbl[0] + 1
					end
				end
			end

			closedir(ptr)

			return tbl
		end

		function fs.get_files_recursive(path, can_traverse)
			if not path:sub(-1) ~= "/" then
				path = path .. "/"
			end

			local out = {}
			
			-- TODO
			local errors = {}
			
			out[0] = 1
			if not walk(path, out, errors, can_traverse) then
				return nil, errors[1].error
			end
			(out)[0] = nil
			return out, errors[1] and errors or nil
		end
	end

	ffi.cdef("ssize_t sendfile(int out_fd, int in_fd, long int *offset, size_t count);")

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
				links = buff[0].st_nlink
			}
		end

		return nil, last_error()
	end

	do
		local buff = statbox()

		function fs.get_size(path, link)
			local ret = link and stat_func_link(path, buff) or stat_func(path, buff)

			if ret ~= 0 then
				return nil, last_error()
			end

			return tonumber(buff[0].st_size)
		end
	end

	do
		local buff = statbox()

		function fs.get_type(path)
			if stat_func(path, buff) == 0 then
				return bit.band(buff[0].st_mode, DIRECTORY) ~= 0 and "directory" or "file"
			end

			return nil
		end
	end

	ffi.cdef([[
		ssize_t splice(int fd_in, long long *off_in, int fd_out, long long *off_out, size_t lenunsigned, int flags );
		int pipe(int pipefd[2]);
	]])

	local p = ffi.new("int[2]")

	function fs.copy(from, to, permissions)
		local in_ = fs.open(from, "r")
		if in_ == nil then
			return nil, "error opening " .. from .. " for reading: " .. last_error()
		end

		local out_ = fs.open(to, "w")
		if out_ == nil then
			fs.close(in_)
			return nil, "error opening " .. to .. " for writing: " .. last_error()
		end

		in_ = ffi.C.fileno(in_)
		out_ = ffi.C.fileno(out_)

		local size = fs.get_size(from)

		ffi.C.pipe(p)

		local ok, err
		local ret

		while true do
			ret = ffi.C.splice(in_, nil, p[1], nil, size, 0)

			if ret == -1 then
				ok, err = nil, last_error()
				break
			end

			ret = ffi.C.splice(p[0], nil, out_, nil, ret, 0)

			if ret <= 0 then
				if ret == -1 then
					ok, err = nil, last_error()
				else
					ok = true
				end
				break
			end
		end

		if permissions then
			local attr = fs.get_attributes(from)
			if attr then
				ffi.C.fchmod(in_, attr.mode)
			end
		end

		ffi.C.close(p[0])
		ffi.C.close(p[1])

		ffi.C.close(out_)
		ffi.C.close(in_)

		return ok, err
	end

	ffi.cdef([[
        int link(const char *from, const char *to);
        int symlink(const char *from, const char *to);
	]])

	function fs.link(from, to, symbolic)
		if (symbolic and ffi.C.symlink or ffi.C.link)(from, to) ~= 0 then
			return nil, last_error()
		end


		return true
	end

	function fs.create_directory(path)
		if ffi.C.mkdir(path, 448) ~= 0 then
			return nil, last_error()
		end

		return true
	end

	function fs.remove_file(path)
		if ffi.C.remove(path) ~= 0 then
			return nil, last_error()
		end
		return true
	end

	function fs.remove_directory(path)
		if ffi.C.rmdir(path) ~= 0 then
			return nil, last_error()
		end
		return true
	end

	function fs.set_current_directory(path)
		if ffi.C.chdir(path) ~= 0 then
			return nil, last_error()
		end

		return true
	end

	function fs.get_current_directory()
		local temp = ffi.new("char[1024]")
		return ffi.string(ffi.C.getcwd(temp, ffi.sizeof(temp)))
	end
end

return fs
 end
IMPORTS['example_project/src/platforms/socket.nlua'] = function(...) local ffi = require("ffi")
local socket = {}
local e = {}
local errno = {}

do
    local C

    if ffi.os == "Windows" then
        C = assert(ffi.load("ws2_32"))
    else
        C = ffi.C
    end

    local M = {}

    local function generic_function(C_name, cdef, alias, size_error_handling)
        alias = alias or C_name

        ffi.cdef(cdef)

        local func_name = alias
        local func = C[C_name]

        if size_error_handling == false then
            socket[func_name] = func
        elseif size_error_handling then
--[==[
            set_return_type<|ReturnType, Tuple<|number, bit.bor( string,  nil) |>|>]==]

            socket[func_name] = function(...)
                local len = func(...)
                if len < 0 then
                    return nil, "nope"
                end

                return len
            end
        else
--[==[
            set_return_type<|ReturnType, Tuple<| bit.bor(true,  nil) , bit.bor( string,  nil) |>|>]==]

            socket[func_name] = function(...)
                local ret = func(...)

                if ret == 0 then
                    return true
                end

                return nil, "nope"
            end
        end
    end

    ffi.cdef[[
        char *strerror(int errnum);

        struct in_addr {
            uint32_t s_addr;
        };

        struct in6_addr {
            union {
                uint8_t u6_addr8[16];
                uint16_t u6_addr16[8];
                uint32_t u6_addr32[4];
            } u6_addr;
        };
    ]]

    -- https://www.cs.dartmouth.edu/~sergey/cs60/on-sockaddr-structs.txt

    if ffi.os == "OSX" then
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
                struct in_addr sin_addr;
                char sin_zero[8];
            };

            struct sockaddr_in6 {
                uint8_t sin6_len;
                uint8_t sin6_family;
                uint16_t sin6_port;
                uint32_t sin6_flowinfo;
                struct in6_addr sin6_addr;
                uint32_t sin6_scope_id;
            };
        ]]
    elseif ffi.os == "Windows" then
        ffi.cdef[[
            struct sockaddr {
                uint16_t sa_family;
                char sa_data[14];
            };

            struct sockaddr_in {
                int16_t sin_family;
                uint16_t sin_port;
                struct in_addr sin_addr;
                uint8_t sin_zero[8];
            };

            struct sockaddr_in6 {
                int16_t sin6_family;
                uint16_t sin6_port;
                uint32_t sin6_flowinfo;
                struct in6_addr sin6_addr;
                uint32_t sin6_scope_id;
            };
        ]]
    else -- posix
        ffi.cdef[[
            struct sockaddr {
                uint16_t sa_family;
                char sa_data[14];
            };

            struct sockaddr_in {
                uint16_t sin_family;
                uint16_t sin_port;
                struct in_addr sin_addr;
                char sin_zero[8];
            };

            struct sockaddr_in6 {
                uint16_t sin6_family;
                uint16_t sin6_port;
                uint32_t sin6_flowinfo;
                struct in6_addr sin6_addr;
                uint32_t sin6_scope_id;
            };
        ]]
    end

    if ffi.os == "Windows" then
        ffi.cdef[[
            typedef size_t SOCKET;

            struct addrinfo {
                int ai_flags;
                int ai_family;
                int ai_socktype;
                int ai_protocol;
                size_t ai_addrlen;
                char *ai_canonname;
                struct sockaddr *ai_addr;
                struct addrinfo *ai_next;
            };
        ]]
        socket.INVALID_SOCKET = ffi.new("SOCKET", -1)
    elseif ffi.os == "OSX" then
        ffi.cdef[[
            typedef int32_t SOCKET;

            struct addrinfo {
                int ai_flags;
                int ai_family;
                int ai_socktype;
                int ai_protocol;
                uint32_t ai_addrlen;
                char *ai_canonname;
                struct sockaddr *ai_addr;
                struct addrinfo *ai_next;
            };
        ]]
        socket.INVALID_SOCKET = -1
    else
        ffi.cdef[[
            typedef int32_t SOCKET;

            struct addrinfo {
                int ai_flags;
                int ai_family;
                int ai_socktype;
                int ai_protocol;
                uint32_t ai_addrlen;
                struct sockaddr *ai_addr;
                char *ai_canonname;
                struct addrinfo *ai_next;
            };
        ]]
        socket.INVALID_SOCKET = -1
    end

    assert(ffi.sizeof("struct sockaddr") == 16)
    assert(ffi.sizeof("struct sockaddr_in") == 16)

    if ffi.os == "Windows" then
        ffi.cdef[[

            struct pollfd {
                SOCKET fd;
                short events;
                short revents;
            };
            int WSAPoll(struct pollfd *fds, unsigned long int nfds, int timeout);

            uint32_t GetLastError();
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

        local function WORD(low, high)
            return bit.bor(low , bit.lshift(high , 8))
        end

        do
            ffi.cdef[[int GetLastError();]]

            local FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
            local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
            local flags = bit.bor(FORMAT_MESSAGE_IGNORE_INSERTS, FORMAT_MESSAGE_FROM_SYSTEM)

            local cache = {}

            function socket.lasterror(num)
                num = num or ffi.C.GetLastError()

                if not cache[num] then
                    local buffer = ffi.new("char[512]")
                    local len = ffi.C.FormatMessageA(flags, nil, num, 0, buffer, ffi.sizeof(buffer), nil)
                    cache[num] = ffi.string(buffer, len - 2)
                end

                return cache[num], num
            end
        end

        do
            ffi.cdef[[int WSAStartup(uint16_t version, const void *wsa_data);]]

            local wsa_data

            if jit.arch == "x64" then
                wsa_data = ffi.typeof([[struct {
                    uint16_t wVersion;
                    uint16_t wHighVersion;
                    unsigned short iMax_M;
                    unsigned short iMaxUdpDg;
                    char * lpVendorInfo;
                    char szDescription[257];
                    char szSystemStatus[129];
                }]])
            else
                wsa_data = ffi.typeof([[struct {
                    uint16_t wVersion;
                    uint16_t wHighVersion;
                    char szDescription[257];
                    char szSystemStatus[129];
                    unsigned short iMax_M;
                    unsigned short iMaxUdpDg;
                    char * lpVendorInfo;
                }]])
            end

            function socket.initialize()
                local data = wsa_data()

                if C.WSAStartup(WORD(2, 2), data) == 0 then
                    return data
                end

                return nil, socket.lasterror()
            end
        end

        do
            ffi.cdef[[int WSACleanup();]]

            function socket.shutdown()
                if C.WSACleanup() == 0 then
                    return true
                end

                return nil, socket.lasterror()
            end
        end

        if jit.arch ~= "x64" then -- xp or something
            ffi.cdef[[int WSAAddressToStringA(struct sockaddr *, unsigned long, void *, char *, unsigned long *);]]

            function socket.inet_ntop(family, pAddr, strptr, strlen)
                -- win XP: http://memset.wordpress.com/2010/10/09/inet_ntop-for-win32/
                local srcaddr = ffi.new("struct sockaddr_in")
                ffi.copy(srcaddr.sin_addr, pAddr, ffi.sizeof(srcaddr.sin_addr))
                srcaddr.sin_family = family
                local len = ffi.new("unsigned long[1]", strlen)
                C.WSAAddressToStringA(ffi.cast("struct sockaddr *", srcaddr), ffi.sizeof(srcaddr), nil, strptr, len)
                return strptr
            end
        end

        generic_function("closesocket", "int closesocket(SOCKET s);", "close")

        do
            ffi.cdef[[int ioctlsocket(SOCKET s, long cmd, unsigned long* argp);]]

            local IOCPARM_MASK    = 0x7
            local IOC_IN          = 0x80000000
            local function _IOW(x, y, t)
                return bit.bor(IOC_IN, bit.lshift(bit.band(ffi.sizeof(t),IOCPARM_MASK),16), bit.lshift(x,8), y)
            end

            local FIONBIO = _IOW(string.byte'f', 126, "uint32_t") -- -2147195266 -- 2147772030ULL

            function socket.blocking(fd, b)
                local ret = C.ioctlsocket(fd, FIONBIO, ffi.new("int[1]", b and 0 or 1))
                if ret == 0 then
                    return true
                end

                return nil, socket.lasterror()
            end
        end

        function socket.poll(fds, ndfs, timeout)
            local ret = C.WSAPoll(fds, ndfs, timeout)
            if ret < 0 then
                return nil, socket.lasterror()
            end
            return ret
        end
    else
        ffi.cdef[[
            struct pollfd {
                SOCKET fd;
                short events;
                short revents;
            };

            int poll(struct pollfd *fds, unsigned long nfds, int timeout);
        ]]

        do
            local cache = {}

            function socket.lasterror(num)
                num = num or ffi.errno()

                if not cache[num] then
                    local err = ffi.string(ffi.C.strerror(num))
                    cache[num] = err == "" and tostring(num) or err
                end

                return cache[num], num
            end
        end

        generic_function("close", "int close(SOCKET s);")

        do
            ffi.cdef[[int fcntl(int, int, ...);]]

            local F_GETFL = 3
            local F_SETFL = 4
            local O_NONBLOCK = 04000

            if ffi.os == "OSX" then
                O_NONBLOCK = 0x0004
            end
            function socket.blocking(fd, b)
                local flags = ffi.C.fcntl(fd, F_GETFL, 0)

                if flags < 0 then
                    -- error
                    return nil, socket.lasterror()
                end

                if b then
                    flags = bit.band(flags, bit.bnot(O_NONBLOCK))
                else
                    flags = bit.bor(flags, O_NONBLOCK)
                end

                local ret = ffi.C.fcntl(fd, F_SETFL, ffi.new("int", flags))

                if ret < 0 then
                    return nil, socket.lasterror()
                end

                return true
            end
        end

        function socket.poll(fds, ndfs, timeout)
            local ret = C.poll(fds, ndfs, timeout)
            if ret < 0 then
                return nil, socket.lasterror()
            end
            return ret
        end
    end


    ffi.cdef[[
        int getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
        int getnameinfo(const struct sockaddr* sa, uint32_t salen, char* host, size_t hostlen, char* serv, size_t servlen, int flags);
        void freeaddrinfo(struct addrinfo *ai);
        const char *gai_strerror(int errcode);
        char *inet_ntoa(struct in_addr in);
        uint16_t ntohs(uint16_t netshort);
    ]]

    function socket.getaddrinfo(node_name, service_name, hints, result)
        local ret = C.getaddrinfo(node_name, service_name, hints, result)
        if ret == 0 then
            return true
        end

        return nil, ffi.string(C.gai_strerror(ret))
    end

    function socket.getnameinfo(address, length, host, hostlen, serv, servlen, flags)
        local ret = C.getnameinfo(address, length, host, hostlen, serv, servlen, flags)
        if ret == 0 then
            return true
        end

        return nil, ffi.string(C.gai_strerror(ret))
    end

    do
        ffi.cdef[[const char *inet_ntop(int __af, const void *__cp, char *__buf, unsigned int __len);]]

        function socket.inet_ntop(family, addrinfo, strptr, strlen)
            if C.inet_ntop(family, addrinfo, strptr, strlen) == nil then
                return nil, socket.lasterror()
            end

            return strptr
        end
    end

    do
        ffi.cdef[[SOCKET socket(int af, int type, int protocol);]]

        function socket.create(af, type, protocol)
            local fd = C.socket(af, type, protocol)

            if fd <= 0 then
                return nil, socket.lasterror()
            end

            return fd
        end
    end

    generic_function("shutdown", "int shutdown(SOCKET s, int how);")

    generic_function("setsockopt", "int setsockopt(SOCKET s, int level, int optname, const void* optval, uint32_t optlen);")
    generic_function("getsockopt", "int getsockopt(SOCKET s, int level, int optname, void *optval, uint32_t *optlen);")

    generic_function("accept", "SOCKET accept(SOCKET s, struct sockaddr *, int *);", nil, false)
    generic_function("bind", "int bind(SOCKET s, const struct sockaddr* name, int namelen);")
    generic_function("connect", "int connect(SOCKET s, const struct sockaddr * name, int namelen);")

    generic_function("listen", "int listen(SOCKET s, int backlog);")
    generic_function("recv", "int recv(SOCKET s, char* buf, int len, int flags);", nil, true)
    generic_function("recvfrom", "int recvfrom(SOCKET s, char* buf, int len, int flags, struct sockaddr *src_addr, unsigned int *addrlen);", nil, true)

    generic_function("send", "int send(SOCKET s, const char* buf, int len, int flags);", nil, true)
    generic_function("sendto", "int sendto(SOCKET s, const char* buf, int len, int flags, const struct sockaddr* to, int tolen);", nil, true)

    generic_function("getpeername", "int getpeername(SOCKET s, struct sockaddr *, unsigned int *);")
    generic_function("getsockname", "int getsockname(SOCKET s, struct sockaddr *, unsigned int *);")

    socket.inet_ntoa = C.inet_ntoa
    socket.ntohs = C.ntohs

    function socket.poll(fd, events, revents)

    end

    e = {
        TCP_NODELAY = 1,
        TCP_MAXSEG = 2,
        TCP_CORK = 3,
        TCP_KEEPIDLE = 4,
        TCP_KEEPINTVL = 5,
        TCP_KEEPCNT = 6,
        TCP_SYNCNT = 7,
        TCP_LINGER2 = 8,
        TCP_DEFER_ACCEPT = 9,
        TCP_WINDOW_CLAMP = 10,
        TCP_INFO = 11,
        TCP_QUICKACK = 12,
        TCP_CONGESTION = 13,
        TCP_MD5SIG = 14,
        TCP_THIN_LINEAR_TIMEOUTS = 16,
        TCP_THIN_DUPACK = 17,
        TCP_USER_TIMEOUT = 18,
        TCP_REPAIR = 19,
        TCP_REPAIR_QUEUE = 20,
        TCP_QUEUE_SEQ = 21,
        TCP_REPAIR_OPTIONS = 22,
        TCP_FASTOPEN = 23,
        TCP_TIMESTAMP = 24,
        TCP_NOTSENT_LOWAT = 25,
        TCP_CC_INFO = 26,
        TCP_SAVE_SYN = 27,
        TCP_SAVED_SYN = 28,
        TCP_REPAIR_WINDOW = 29,
        TCP_FASTOPEN_CONNECT = 30,
        TCP_ULP = 31,
        TCP_MD5SIG_EXT = 32,
        TCP_FASTOPEN_KEY = 33,
        TCP_FASTOPEN_NO_COOKIE = 34,
        TCP_ZEROCOPY_RECEIVE = 35,
        TCP_INQ = 36,

        AF_INET = 2,
        AF_INET6 = 10,
        AF_UNSPEC = 0,

        AF_UNIX = 1,
        AF_AX25 = 3,
        AF_IPX = 4,
        AF_APPLETALK = 5,
        AF_NETROM = 6,
        AF_BRIDGE = 7,
        AF_AAL5 = 8,
        AF_X25 = 9,

        INET6_ADDRSTRLEN = 46,
        INET_ADDRSTRLEN = 16,

        SO_DEBUG = 1,
        SO_REUSEADDR = 2,
        SO_TYPE = 3,
        SO_ERROR = 4,
        SO_DONTROUTE = 5,
        SO_BROADCAST = 6,
        SO_SNDBUF = 7,
        SO_RCVBUF = 8,
        SO_SNDBUFFORCE = 32,
        SO_RCVBUFFORCE = 33,
        SO_KEEPALIVE = 9,
        SO_OOBINLINE = 10,
        SO_NO_CHECK = 11,
        SO_PRIORITY = 12,
        SO_LINGER = 13,
        SO_BSDCOMPAT = 14,
        SO_REUSEPORT = 15,
        SO_PASSCRED = 16,
        SO_PEERCRED = 17,
        SO_RCVLOWAT = 18,
        SO_SNDLOWAT = 19,
        SO_RCVTIMEO = 20,
        SO_SNDTIMEO = 21,
        SO_SECURITY_AUTHENTICATION = 22,
        SO_SECURITY_ENCRYPTION_TRANSPORT = 23,
        SO_SECURITY_ENCRYPTION_NETWORK = 24,
        SO_BINDTODEVICE = 25,
        SO_ATTACH_FILTER = 26,
        SO_DETACH_FILTER = 27,
        SO_GET_FILTER = 26,
        SO_PEERNAME = 28,
        SO_TIMESTAMP = 29,
        SO_ACCEPTCONN = 30,
        SO_PEERSEC = 31,
        SO_PASSSEC = 34,
        SO_TIMESTAMPNS = 35,
        SO_MARK = 36,
        SO_TIMESTAMPING = 37,
        SO_PROTOCOL = 38,
        SO_DOMAIN = 39,
        SO_RXQ_OVFL = 40,
        SO_WIFI_STATUS = 41,
        SO_PEEK_OFF = 42,
        SO_NOFCS = 43,
        SO_LOCK_FILTER = 44,
        SO_SELECT_ERR_QUEUE = 45,
        SO_BUSY_POLL = 46,
        SO_MAX_PACING_RATE = 47,
        SO_BPF_EXTENSIONS = 48,
        SO_INCOMING_CPU = 49,
        SO_ATTACH_BPF = 50,
        SO_DETACH_BPF = 27,
        SO_ATTACH_REUSEPORT_CBPF = 51,
        SO_ATTACH_REUSEPORT_EBPF = 52,
        SO_CNX_ADVICE = 53,
        SO_MEMINFO = 55,
        SO_INCOMING_NAPI_ID = 56,
        SO_COOKIE = 57,
        SO_PEERGROUPS = 59,
        SO_ZEROCOPY = 60,
        SO_TXTIME = 61,
        SOL_SOCKET = 1,
        SOL_TCP = 6,

        SOMAXCONN = 128,

        IPPROTO_IP = 0,
        IPPROTO_HOPOPTS = 0,
        IPPROTO_ICMP = 1,
        IPPROTO_IGMP = 2,
        IPPROTO_IPIP = 4,
        IPPROTO_TCP = 6,
        IPPROTO_EGP = 8,
        IPPROTO_PUP = 12,
        IPPROTO_UDP = 17,
        IPPROTO_IDP = 22,
        IPPROTO_TP = 29,
        IPPROTO_DCCP = 33,
        IPPROTO_IPV6 = 41,
        IPPROTO_ROUTING = 43,
        IPPROTO_FRAGMENT = 44,
        IPPROTO_RSVP = 46,
        IPPROTO_GRE = 47,
        IPPROTO_ESP = 50,
        IPPROTO_AH = 51,
        IPPROTO_ICMPV6 = 58,
        IPPROTO_NONE = 59,
        IPPROTO_DSTOPTS = 60,
        IPPROTO_MTP = 92,
        IPPROTO_ENCAP = 98,
        IPPROTO_PIM = 103,
        IPPROTO_COMP = 108,
        IPPROTO_SCTP = 132,
        IPPROTO_UDPLITE = 136,
        IPPROTO_RAW = 255,

        SOCK_STREAM = 1,
        SOCK_DGRAM = 2,
        SOCK_RAW = 3,
        SOCK_RDM = 4,
        SOCK_SEQPACKET = 5,
        SOCK_DCCP = 6,
        SOCK_PACKET = 10,
        SOCK_CLOEXEC = 02000000,
        SOCK_NONBLOCK = 04000,

        AI_PASSIVE = 0x00000001,
        AI_CANONNAME = 0x00000002,
        AI_NUMERICHOST = 0x00000004,
        AI_NUMERICSERV = 0x00000008,
        AI_ALL = 0x00000100,
        AI_ADDRCONFIG = 0x00000400,
        AI_V4MAPPED = 0x00000800,
        AI_NON_AUTHORITATIVE = 0x00004000,
        AI_SECURE = 0x00008000,
        AI_RETURN_PREFERRED_NAMES = 0x00010000,
        AI_FQDN = 0x00020000,
        AI_FILESERVER = 0x00040000,

        POLLIN = 0x0001,
        POLLPRI = 0x0002,
        POLLOUT = 0x0004,
        POLLRDNORM = 0x0040,
        POLLWRNORM = 0x0004,
        POLLRDBAND = 0x0080,
        POLLWRBAND = 0x0100,
        POLLEXTEND = 0x0200,
        POLLATTRIB = 0x0400,
        POLLNLINK = 0x0800,
        POLLWRITE = 0x1000,
        POLLERR = 0x0008,
        POLLHUP = 0x0010,
        POLLNVAL = 0x0020,

        MSG_OOB = 0x01,
        MSG_PEEK = 0x02,
        MSG_DONTROUTE = 0x04,
        MSG_CTRUNC = 0x08,
        MSG_PROXY = 0x10,
        MSG_TRUNC = 0x20,
        MSG_DONTWAIT = 0x40,
        MSG_EOR = 0x80,
        MSG_WAITALL = 0x100,
        MSG_FIN = 0x200,
        MSG_SYN = 0x400,
        MSG_CONFIRM = 0x800,
        MSG_RST = 0x1000,
        MSG_ERRQUEUE = 0x2000,
        MSG_NOSIGNAL = 0x4000,
        MSG_MORE = 0x8000,
        MSG_WAITFORONE = 0x10000,
        MSG_CMSG_CLOEXEC = 0x40000000,
    }

    errno = {
        EAGAIN = 11,
        EWOULDBLOCK = errno.EAGAIN,
        ENOTSOCK = 88,
        ECONNRESET = 104,
        EINPROGRESS = 115,
    }

    if ffi.os == "Windows" then
        e.SO_SNDLOWAT = 4099
        e.SO_REUSEADDR = 4
        e.SO_KEEPALIVE = 8
        e.SOMAXCONN = 2147483647
        e.AF_INET6 = 23
        e.SO_RCVTIMEO = 4102
        e.SOL_SOCKET = 65535
        e.SO_LINGER = 128
        e.SO_OOBINLINE = 256
        e.POLLWRNORM = 16
        e.SO_ERROR = 4103
        e.SO_BROADCAST = 32
        e.SO_ACCEPTCONN = 2
        e.SO_RCVBUF = 4098
        e.SO_SNDTIMEO = 4101
        e.POLLIN = 768
        e.POLLPRI = 1024
        e.SO_TYPE = 4104
        e.POLLRDBAND = 512
        e.POLLWRBAND = 32
        e.SO_SNDBUF = 4097
        e.POLLNVAL = 4
        e.POLLHUP = 2
        e.POLLERR = 1
        e.POLLRDNORM = 256
        e.SO_DONTROUTE = 16
        e.SO_RCVLOWAT = 4100

        errno.EAGAIN = 10035 -- Note: Does not exist on Windows
        errno.EWOULDBLOCK = 10035
        errno.EINPROGRESS = 10036
        errno.ENOTSOCK = 10038
        errno.ECONNRESET = 10054
    end

    if ffi.os == "OSX" then
        e.SOL_SOCKET = 0xffff
        e.SO_DEBUG = 0x0001
        e.SO_ACCEPTCONN = 0x0002
        e.SO_REUSEADDR = 0x0004
        e.SO_KEEPALIVE = 0x0008
        e.SO_DONTROUTE = 0x0010
        e.SO_BROADCAST = 0x0020

        errno.EAGAIN = 35
        errno.EWOULDBLOCK = errno.EAGAIN
        errno.EINPROGRESS = 36
        errno.ENOTSOCK = 38
        errno.ECONNRESET = 54
    end

    if socket.initialize then
        assert(socket.initialize())
    end
end

local function capture_flags(what)
    local flags = {}
    local reverse = {}
    for k, v in pairs(e) do
        if k:sub(0, #what) == what then
            k = k:sub(#what + 1):lower()
            reverse[v] = k
            flags[k] = v
        end
    end
    return {
        lookup = flags,
        reverse = reverse,
        strict_reverse = function(key)
            if not key then
                error("invalid " .. what .. " flag: nil")
            end
            if not reverse[key] then
                error("invalid " .. what .." flag: " .. key, 2)
            end
            return reverse[key]
        end,
        strict_lookup = function(key)
            if not key then
                error("invalid " .. what .. " flag: nil")
            end
            if not flags[key] then
                error("invalid "..what.." flag: " .. key, 2)
            end
            return flags[key]
        end
    }
end

local SOCK = capture_flags("SOCK_")
local AF = capture_flags("AF_")
local IPPROTO = capture_flags("IPPROTO_")
local AI = capture_flags("AI_")
local SOL = capture_flags("SOL_")
local SO = capture_flags("SO_")
local TCP = capture_flags("TCP_")
local POLL = capture_flags("POLL")
local MSG = capture_flags("MSG_")

local function table_to_flags(flags, valid_flags, operation)
	if type(flags) == "string" then
		flags = {flags}
    end
    operation = operation or bit.band

	local out = 0

	for k, v in pairs(flags) do
		local flag = valid_flags[v] or valid_flags[k]
		if not flag or not tonumber(flag) then
            error("invalid flag " .. tostring(v), 2)
		end

		out = operation(out, tonumber(flag) or 0)
	end

	return out
end

local function flags_to_table(flags, valid_flags, operation)
    if not flags then return valid_flags.default_valid_flag end
    operation = operation or bit.band

	local out = {}

	for k, v in pairs(valid_flags) do
		if operation(flags, v) > 0 then
			out[k] = true
		end
	end

	return out
end

local M = {}

local timeout_messages = {}
timeout_messages[errno.EINPROGRESS] = true
timeout_messages[errno.EAGAIN] = true
timeout_messages[errno.EWOULDBLOCK] = true

function M.poll(sock, flags, timeout)
    local pfd = ffi.new("struct pollfd[1]", {{
        fd = sock.fd,
        events = table_to_flags(flags, POLL.lookup, bit.bor),
        revents = 0,
    }})
    local ok, err = socket.poll(pfd, 1, timeout or 0)
    if not ok then return ok, err end
    return flags_to_table(pfd[0].revents, POLL.lookup, bit.bor), ok
end

local function addrinfo_get_ip(self)
    if self.addrinfo.ai_addr == nil then
        return nil
    end
    local str = ffi.new("char[256]")
    local addr = assert(socket.inet_ntop(AF.lookup[self.family], self.addrinfo.ai_addr.sa_data, str, ffi.sizeof(str)))
    return ffi.string(addr)
end

local function addrinfo_get_port(self)
    if self.addrinfo.ai_addr == nil then
        return nil
    end
    if self.family == "inet" then
        return ffi.cast("struct sockaddr_in*", self.addrinfo.ai_addr).sin_port
    elseif self.family == "inet6" then
        return ffi.cast("struct sockaddr_in6*", self.addrinfo.ai_addr).sin6_port
    end

    return nil, "unknown family " .. tostring(self.family)
end

local function addrinfo_to_table(res, host, service)
    local info = {}

    if res.ai_canonname ~= nil then
        info.canonical_name = ffi.string(res.ai_canonname)
    end

    info.host = host ~= "*" and host or nil
    info.service = service
    info.family = AF.reverse[res.ai_family]
    info.socket_type = SOCK.reverse[res.ai_socktype]
    info.protocol = IPPROTO.reverse[res.ai_protocol]
    info.flags = flags_to_table(res.ai_flags, AI.lookup, bit.band)
    info.addrinfo = res
    info.get_ip = addrinfo_get_ip
    info.get_port = addrinfo_get_port

    return info
end

function M.get_address_info(data)
    local hints

    if data.socket_type or data.protocol or data.flags or data.family then
        hints = ffi.new("struct addrinfo", {
            ai_family = data.family and AF.strict_lookup(data.family) or nil,
            ai_socktype = data.socket_type and SOCK.strict_lookup(data.socket_type) or nil,
            ai_protocol = data.protocol and IPPROTO.strict_lookup(data.protocol) or nil,
            ai_flags = data.flags and table_to_flags(data.flags, AI.lookup, bit.bor) or nil,
        })
    end

    local out = ffi.new("struct addrinfo*[1]")

    local ok, err = socket.getaddrinfo(
        data.host ~= "*" and data.host or nil,
        data.service and tostring(data.service) or nil,
        hints,
        out
    )

    if not ok then return ok, err end

    local tbl = {}

    local res = out[0]

    while res ~= nil do
        table.insert(tbl, addrinfo_to_table(res, data.host, data.service))

        res = res.ai_next
    end

    --ffi.C.freeaddrinfo(out[0])

    return tbl
end

function M.find_first_address(host, service, options)
    options = options or {}

    local info = {}
    info.host = host
    info.service = service

    info.family = options.family or "inet"
    info.socket_type = options.socket_type or "stream"
    info.protocol = options.protocol or "tcp"
    info.flags = options.flags

    if host == "*" then
        info.flags = info.flags or {}
        table.insert(info.flags, "passive")
    end

    local addrinfo, err = M.get_address_info(info)

    if not addrinfo then
        return nil, err
    end

    if not addrinfo[1] then
        return nil, "no addresses found (empty address info table)"
    end

    for _, v in ipairs(addrinfo) do
        if v.family == info.family and v.socket_type == info.socket_type and v.protocol == info.protocol then
            return v
        end
    end

    return addrinfo[1]
end


do
    local meta = {}
    meta.__index = meta

    function meta:__tostring()
        return string.format("socket[%s-%s-%s][%s]", self.family, self.socket_type, self.protocol, self.fd)
    end

    function M.create(family, socket_type, protocol)
        local fd, err, num = socket.create(AF.strict_lookup(family), SOCK.strict_lookup(socket_type), IPPROTO.strict_lookup(protocol))

        if not fd then return fd, err, num end

        return setmetatable({
            fd = fd,
            family = family,
            socket_type = socket_type,
            protocol = protocol,
            blocking = true,
        }, meta)
    end

    function meta:close()
        if self.on_close then
            self:on_close()
        end
        return socket.close(self.fd)
    end

    function meta:set_blocking(b)
        local ok, err, num = socket.blocking(self.fd, b)
        if ok then
            self.blocking = b
        end
        return ok, err, num
    end

    function meta:set_option(key, val, level)
        level = level or "socket"

        if type(val) == "boolean" then
            val = ffi.new("int[1]", val and 1 or 0)
        elseif type(val) == "number" then
            val = ffi.new("int[1]", val)
        elseif type(val) ~= "cdata" then
            error("unknown value type: " .. type(val))
        end

        local env = SO
        if level == "tcp" then
            env = TCP
        end

        return socket.setsockopt(self.fd, SOL.strict_lookup(level), env.strict_lookup(key), ffi.cast("void *", val), ffi.sizeof(val))
    end

    function meta:connect(host, service)
        local res

        if type(host) == "table" and host.addrinfo then
            res = host
        else
            local res_, err = M.find_first_address(host, service, {
                family = self.family,
                socket_type = self.socket_type,
                protocol = self.protocol
            })

            if not res_ then
                return res_, err
            end

            res = res_
        end

        local ok, err, num = socket.connect(self.fd, res.addrinfo.ai_addr, res.addrinfo.ai_addrlen)

        if not ok and not self.blocking then
            if timeout_messages[num] then
                self.timeout_connected = {host, service}
                return true
            end
        elseif self.on_connect then
            self:on_connect(host, service)
        end

        if not ok then
            return ok, err, num
        end

        return true
    end

    function meta:poll_connect()
        if self.on_connect and self.timeout_connected and self:is_connected() then
            local ok, err, num = self:on_connect(unpack(self.timeout_connected))
            self.timeout_connected = nil
            return ok, err, num
        end

        return nil, "timeout"
    end

    function meta:bind(host, service)
        if host == "*" then
            host = nil
        end

        if type(service) == "number" then
            service = tostring(service)
        end

        local res

        if type(host) == "table" and host.addrinfo then
            res = host
        else
            local res_, err = M.find_first_address(host, service, {
                family = self.family,
                socket_type = self.socket_type,
                protocol = self.protocol
            })

            if not res_ then
                return res_, err
            end

            res = res_
        end

        return socket.bind(self.fd, res.addrinfo.ai_addr, res.addrinfo.ai_addrlen)
    end

    function meta:listen(max_connections)
        max_connections = max_connections or e.SOMAXCONN
        return socket.listen(self.fd, max_connections)
    end

    function meta:accept()
        local address = ffi.new("struct sockaddr_in[1]")
        local fd, err = socket.accept(self.fd, ffi.cast("struct sockaddr *", address), ffi.new("unsigned int[1]", ffi.sizeof(address)))

        if fd ~= socket.INVALID_SOCKET then
            local client = setmetatable({
                fd = fd,
                family = "unknown",
                socket_type = "unknown",
                protocol = "unknown",
                blocking = true,
            }, meta)

            if self.debug then
                print(tostring(self), ": accept client: ", tostring(client))
            end

            return client
        end

        local err, num = socket.lasterror()

        if not self.blocking and timeout_messages[num] then
            return nil, "timeout", num
        end

        if self.debug then
            print(tostring(self), ": accept error", num, ":", err)
        end

        return nil, err, num
    end

    function meta:is_connected()
        local ip, service, num = self:get_peer_name()
        local ip2, service2, num2 = self:get_name()

        if not ip and (num == errno.ECONNRESET or num == errno.ENOTSOCK) then
            return false, service, num
        end

        if ffi.os == "Windows" then
            return ip ~= "0.0.0.0" and ip2 ~= "0.0.0.0" and service ~= 0 and service2 ~= 0
        else
            return ip and ip2 and service ~= 0 and service2 ~= 0
        end
    end

    function meta:get_peer_name()
        local data = ffi.new("struct sockaddr_in")
        local len = ffi.new("unsigned int[1]", ffi.sizeof(data))

        local ok, err, num = socket.getpeername(self.fd, ffi.cast("struct sockaddr *", data), len)
        if not ok then return ok, err, num end

        return ffi.string(socket.inet_ntoa(data.sin_addr)), socket.ntohs(data.sin_port)
    end

    function meta:get_name()
        local data = ffi.new("struct sockaddr_in")
        local len = ffi.new("unsigned int[1]", ffi.sizeof(data))

        local ok, err, num = socket.getsockname(self.fd, ffi.cast("struct sockaddr *", data), len)
        if not ok then return ok, err, num end

        return ffi.string(socket.inet_ntoa(data.sin_addr)), socket.ntohs(data.sin_port)
    end

    local default_flags

    if ffi.os ~= "Windows" then
        default_flags = {"nosignal"}
    end

    function meta:send_to(addr, data, flags)
        return self:send(data, table_to_flags(flags, MSG.lookup), addr)
    end

    function meta:send(data, flags, addr)
        flags = flags or default_flags

        if self.on_send then
            return self:on_send(data, flags)
        end

        local len, err, num

        if addr then
            len, err, num = socket.sendto(self.fd, data, #data, table_to_flags(flags, MSG.lookup), addr.addrinfo.ai_addr, addr.addrinfo.ai_addrlen)
        else
            len, err, num = socket.send(self.fd, data, #data, table_to_flags(flags, MSG.lookup))
        end

        if not len then
            return len, err, num
        end

        if len > 0 then
            return len
        end
    end

    function meta:receive_from(address, size, flags)
        local src_addr
        local src_addr_size

        if not address then
            src_addr = ffi.new("struct sockaddr_in[1]")
            src_addr_size = ffi.sizeof("struct sockaddr_in")
        else
            src_addr = address.addrinfo.ai_addr
            src_addr_size = address.addrinfo.ai_addrlen
        end

        return self:receive(size, flags, src_addr, src_addr_size)
    end

    function meta:receive(size, flags, src_address, address_len)
        size = size or 64000
        local buff = ffi.new("char[?]", size)

        if self.on_receive then
            return self:on_receive(buff, size, flags)
        end

        local len, err, num
        local len_res

        if src_address then
            len_res = ffi.new("int[1]", address_len)
            len, err, num = socket.recvfrom(self.fd, buff, ffi.sizeof(buff), flags or 0, ffi.cast("struct sockaddr *", src_address), len_res)
        else
            len, err, num = socket.recv(self.fd, buff, ffi.sizeof(buff), flags or 0)
        end

        if num == errno.ECONNRESET then
            self:close()
            if self.debug then
                print(tostring(self), ": closed")
            end

            return nil, "closed", num
        end

        if not len then
            if not self.blocking and timeout_messages[num] then
                return nil, "timeout", num
            end

            if self.debug then
                print(tostring(self), " error", num, ":", err)
            end

            return len, err, num
        end

        if len > 0 then
            if self.debug then
                print(tostring(self), ": received ", len, " bytes")
            end

            if src_address then
                return ffi.string(buff, len), {
                    addrinfo = {
                        ai_addr = ffi.cast("struct sockaddr *", src_address),
                        ai_addrlen = len_res[0],
                    },
                    family = self.family,
                    get_port = addrinfo_get_port,
                    get_ip = addrinfo_get_ip,
                }
            end

            return ffi.string(buff, len)
        end

        return nil, err, num
    end
end

function M.bind(host, service)
    local info, err = M.find_first_address(host, service, {
        family = "inet",
        socket_type = "stream",
        protocol = "tcp",
        flags = {"passive"},
    })

    if not info then
        return info, err
    end

    local server, err, num = M.create(info.family, info.socket_type, info.protocol)

    if not server then
        return server, err, num
    end

    server:set_option("reuseaddr", 1)

    local ok, err, num = server:bind(info)

    if not ok then
        return ok, err, num
    end

    server:set_option("sndbuf", 65536)
    server:set_option("rcvbuf", 65536)

    return server
end

return M end
local fs =( IMPORTS['example_project/src/platforms/unix/filesystem.nlua']("platforms/unix/filesystem.nlua"))
local socket =( IMPORTS['example_project/src/platforms/socket.nlua']("platforms/socket.nlua"))--§analyzer:AnalyzeUnreachableCode() 
--[==[

print<|fs|>]==] -- typesystem call, it won't be in build output