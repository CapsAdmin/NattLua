local ffi = require("ffi")
local fs = {}

if ffi.arch ~= "Windows" then
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
            char name [];
        };
        int inotify_init(void);
        int inotify_init1(int flags);
        int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
        int inotify_rm_watch(int fd, int wd);

        static const uint32_t IN_MODIFY = 0x00000002;
    ]])
	local O_RDONLY = 0x0000 -- open for reading only
	local O_WRONLY = 0x0001 -- open for writing only
	local O_RDWR = 0x0002 -- open for reading and writing
	local O_NONBLOCK = 0x0004 -- no delay
	local O_APPEND = 0x0008 -- set append mode
	local O_SHLOCK = 0x0010 -- open with shared file lock
	local O_EXLOCK = 0x0020 -- open with exclusive file lock
	local O_ASYNC = 0x0040 -- signal pgrp when data ready
	local O_NOFOLLOW = 0x0100 -- don't follow symlinks
	local O_CREAT = 0x0200 -- create if nonexistant
	local O_TRUNC = 0x0400 -- truncate to zero length
	local O_EXCL = 0x0800 -- error if already exists
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

	-- NOTE: 64bit version
	if jit.os == "OSX" then
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

	if jit.os == "OSX" then
		stat_func = ffi.C.stat64
		stat_func_link = ffi.C.lstat64
	else
		local arch = jit.arch
		stat_func = function(path, buff)
			return ffi.C.syscall(arch == "x64" and 4 or 195, path, buff)
		end
		stat_func_link = function(path, buff)
			return ffi.C.syscall(arch == "x64" and 6 or 196, path, buff)
		end
	end

	ffi.cdef([[
        int setxattr(const char *path, const char *name, const void *value, size_t size, int flags);
        ssize_t getxattr(const char *path, const char *name, void *value, size_t size);
    ]])

	function fs.setcustomattribute(path, data)
		if ffi.C.setxattr(path, "goluwa_attributes", data, #data, 0x2) ~= 0 then
			return nil, last_error()
		end

		return true
	end

	function fs.getcustomattribute(path)
		local size = ffi.C.getxattr(path, "goluwa_attributes", nil, 0)

		if size == -1 then return nil, last_error() end

		local buffer = ffi.string("char[?]", size)
		ffi.C.getxattr(path, "goluwa_attributes", buffer, size)
		return ffi.string(buffer)
	end

	if jit.os ~= "OSX" then
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

		function fs.watch(path, mask)
			local wd = ffi.C.inotify_add_watch(fd, path, mask and utility.TableToFlags(mask, flags) or 4095)
			queue[wd] = {}
			local self = {}

			function self:Read()
				local len = ffi.C.read(fd, buffer, length)

				if len >= length then
					local res = ffi.cast("struct inotify_event*", buffer)
					list.insert(
						queue[res.wd],
						{
							cookie = res.cookie,
							name = ffi.string(res.name, res.len),
							flags = utility.FlagsToTable(res.mask, flags),
						}
					)
				end

				if queue[wd][1] then return list.remove(queue[wd]) end
			end

			function self:Remove()
				ffi.C.inotify_rm_watch(inotify_fd, wd)
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
					if ptr[1] == dot and ptr[2] == 0 then return true end

					if ptr[1] == 0 then return true end
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

				if ptr == nil then return nil, last_error() end

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
					list.insert(errors, {path = path, error = last_error()})
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
				if not path:sub(-1) ~= "/" then path = path .. "/" end

				local out = {}
				local errors = {}
				out[0] = 1

				if not walk(path, out, errors, can_traverse) then
					return nil, errors[1].error
				end

				out[0] = nil
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
					links = buff[0].st_nlink,
				}
			end

			return nil, last_error()
		end

		do
			local buff = statbox()

			function fs.get_size(path, link)
				local ret = link and stat_func_link(path, buff) or stat_func(path, buff)

				if ret ~= 0 then return nil, last_error() end

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

			if permissions then ffi.C.fchmod(in_, fs.get_attributes(from).mode) end

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
			if ffi.C.mkdir(path, 448) ~= 0 then return nil, last_error() end

			return true
		end

		function fs.remove_file(path)
			if ffi.C.remove(path) ~= 0 then return nil, last_error() end

			return true
		end

		function fs.remove_directory(path)
			if ffi.C.rmdir(path) ~= 0 then return nil, last_error() end

			return true
		end

		function fs.set_current_directory(path)
			if ffi.C.chdir(path) ~= 0 then return nil, last_error() end

			return true
		end

		function fs.get_current_directory()
			local temp = ffi.new("char[1024]")
			return ffi.string(ffi.C.getcwd(temp, ffi.sizeof(temp)))
		end
	end
else
	local fs = _G.fs or {}
	local ffi = require("ffi")
	ffi.cdef([[
void *fopen(const char *filename, const char *mode);
size_t fread(void *ptr, size_t size, size_t nmemb, void *stream);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, void *stream);
int fseek(void *stream, long offset, int whence);
long int ftell ( void * stream );
int fclose(void *fp);
int feof(void *stream);
]])
	fs.open = ffi.C.fopen
	fs.read = ffi.C.fread
	fs.write = ffi.C.fwrite
	fs.seek = ffi.C.fseek
	fs.tell = ffi.C.ftell
	fs.close = ffi.C.fclose
	fs.eof = ffi.C.feof
	ffi.cdef([[
	typedef struct goluwa_file_time {
		unsigned long high;
		unsigned long low;
	} goluwa_file_time;

	typedef struct goluwa_find_data {
	  unsigned long dwFileAttributes;

	  goluwa_file_time ftCreationTime;
	  goluwa_file_time ftLastAccessTime;
	  goluwa_file_time ftLastWriteTime;

	  unsigned long nFileSizeHigh;
	  unsigned long nFileSizeLow;

	  unsigned long dwReserved0;
	  unsigned long dwReserved1;

	  char cFileName[260];
	  char cAlternateFileName[14];
	} goluwa_find_data;

	void *FindFirstFileA(const char *lpFileName, goluwa_find_data *find_data);
	int FindNextFileA(void *handle, goluwa_find_data *find_data);
	int FindClose(void *);

	unsigned long GetCurrentDirectoryA(unsigned long length, char *buffer);
	int SetCurrentDirectoryA(const char *path);

	int CreateDirectoryA(const char *path, void *lpSecurityAttributes);

	typedef struct goluwa_file_attributes {
		unsigned long dwFileAttributes;
		goluwa_file_time ftCreationTime;
		goluwa_file_time ftLastAccessTime;
		goluwa_file_time ftLastWriteTime;
		unsigned long nFileSizeHigh;
		unsigned long nFileSizeLow;
	} goluwa_file_attributes;

	int GetFileAttributesExA(
	  const char *lpFileName,
	  int fInfoLevelId,
	  goluwa_file_attributes *lpFileInformation
	);

	long GetFileAttributesA(const char *);


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
	
	int CreateSymbolicLinkA(const char *from, const char *to, int16_t flags);
	int CreateHardLinkA(const char *from, const char *to, void *lpSecurityAttributes);
	int CopyFileA(const char *from, const char *to, int fail_if_exists);
	int DeleteFileA(const char *path);
	int RemoveDirectoryA(const char *path);

]])
	local error_str = ffi.new("uint8_t[?]", 1024)
	local FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
	local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
	local error_flags = bit.bor(FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS)

	local function error_string()
		local code = ffi.C.GetLastError()
		local numout = ffi.C.FormatMessageA(error_flags, nil, code, 0, error_str, 1023, nil)
		local err = numout ~= 0 and ffi.string(error_str, numout)

		if err and err:sub(-2) == "\r\n" then return err:sub(0, -3) end

		return err
	end

	local data = ffi.new("goluwa_find_data[1]")
	local flags = {
		archive = 0x20, -- A file or directory that is an archive file or directory. Applications typically use this attribute to mark files for backup or removal .
		compressed = 0x800, -- A file or directory that is compressed. For a file, all of the data in the file is compressed. For a directory, compression is the default for newly created files and subdirectories.
		device = 0x40, -- This value is reserved for system use.
		directory = 0x10, -- The handle that identifies a directory.
		encrypted = 0x4000, -- A file or directory that is encrypted. For a file, all data streams in the file are encrypted. For a directory, encryption is the default for newly created files and subdirectories.
		hidden = 0x2, -- The file or directory is hidden. It is not included in an ordinary directory listing.
		integrity_stream = 0x8000, -- The directory or user data stream is configured with integrity (only supported on ReFS volumes). It is not included in an ordinary directory listing. The integrity setting persists with the file if it's renamed. If a file is copied the destination file will have integrity set if either the source file or destination directory have integrity set.
		normal = 0x80, -- A file that does not have other attributes set. This attribute is valid only when used alone.
		not_content_indexed = 0x2000, -- The file or directory is not to be indexed by the content indexing service.
		no_scrub_data = 0x20000, -- The user data stream not to be read by the background data integrity scanner (AKA scrubber). When set on a directory it only provides inheritance. This flag is only supported on Storage Spaces and ReFS volumes. It is not included in an ordinary directory listing.
		offline = 0x1000, -- The data of a file is not available immediately. This attribute indicates that the file data is physically moved to offline storage. This attribute is used by Remote Storage, which is the hierarchical storage management software. Applications should not arbitrarily change this attribute.
		readonly = 0x1, -- A file that is read-only. Applications can read the file, but cannot write to it or delete it. This attribute is not honored on directories. For more information, see You cannot view or change the Read-only or the System attributes of folders in Windows Server 2003, in Windows XP, in Windows Vista or in Windows 7.
		reparse_point = 0x400, -- A file or directory that has an associated reparse point, or a file that is a symbolic link.
		sparse_file = 0x200, -- A file that is a sparse file.
		system = 0x4, -- A file or directory that the operating system uses a part of, or uses exclusively.
		temporary = 0x100, -- A file that is being used for temporary storage. File systems avoid writing data back to mass storage if sufficient cache memory is available, because typically, an application deletes a temporary file after the handle is closed. In that scenario, the system can entirely avoid writing the data. Otherwise, the data is written after the handle is closed.
		virtual = 0x10000, -- This value is reserved for system use.
	}

	local function flags_to_table(bits)
		local out = {}

		for k, v in pairs(flags) do
			out[k] = bit.bor(bits, v) == v
		end

		return out
	end

	local time_type = ffi.typeof("uint64_t *")
	local ffi_cast = ffi.cast
	local tonumber = tonumber
	local POSIX_TIME = function(ptr)
		return tonumber(ffi_cast(time_type, ptr)[0] / 10000000 - 11644473600)
	end

	function fs.get_attributes(path)
		local info = ffi.new("goluwa_file_attributes[1]")

		if ffi.C.GetFileAttributesExA(path, 0, info) == 0 then
			return nil, error_string()
		end

		return {
			raw_info = info[0],
			creation_time = POSIX_TIME(info[0].ftCreationTime),
			last_accessed = POSIX_TIME(info[0].ftLastAccessTime),
			last_modified = POSIX_TIME(info[0].ftLastWriteTime),
			last_changed = -1, -- last permission changes
			size = info[0].nFileSizeLow,
			type = bit.band(info[0].dwFileAttributes, flags.directory) == flags.directory and
				"directory" or
				"file",
		}
	end

	do
		local info = ffi.new("goluwa_file_attributes[1]")

		function fs.get_type(path)
			if ffi.C.GetFileAttributesExA(path, 0, info) == 0 then return nil end

			return bit.band(info[0].dwFileAttributes, flags.directory) == flags.directory and
				"directory" or
				"file"
		end
	end

	do
		do
			local dot = string.byte(".")

			local function is_dots(ptr)
				if ptr[0] == dot then
					if ptr[1] == dot and ptr[2] == 0 then return true end

					if ptr[1] == 0 then return true end
				end

				return false
			end

			local FindFirstFileA = ffi.C.FindFirstFileA
			local FindClose = ffi.C.FindClose
			local FindNextFileA = ffi.C.FindNextFileA
			local ffi_cast = ffi.cast
			local ffi_string = ffi.string
			local INVALID_FILE = ffi.cast("void *", 0xffffffffffffffffULL)

			function fs.get_files(dir)
				if path == "" then path = "." end

				if dir:sub(-1) ~= "/" then dir = dir .. "/" end

				local handle = FindFirstFileA(dir .. "*", data)

				if handle == nil then return nil, error_string() end

				local out = {}

				if handle ~= INVALID_FILE then
					local i = 1

					repeat
						if not is_dots(data[0].cFileName) then
							out[i] = ffi_string(data[0].cFileName)
							i = i + 1
						end					
					until FindNextFileA(handle, data) == 0

					if FindClose(handle) == 0 then return nil, error_string() end
				end

				return out
			end

			local function walk(path, tbl, errors)
				local handle = FindFirstFileA(path .. "*", data)

				if handle == nil then
					list.insert(errors, {path = path, error = error_string()})
					return
				end

				tbl[tbl[0]] = path
				tbl[0] = tbl[0] + 1

				if handle ~= INVALID_FILE then
					local i = 1

					repeat
						if not is_dots(data[0].cFileName) then
							local name = path .. ffi_string(data[0].cFileName)

							if bit.band(data[0].dwFileAttributes, flags.directory) == flags.directory then
								walk(name .. "/", tbl, errors)
							else
								tbl[tbl[0]] = name
								tbl[0] = tbl[0] + 1
							end
						end					
					until FindNextFileA(handle, data) == 0

					if FindClose(handle) == 0 then return nil, error_string() end
				end

				return tbl
			end

			function fs.get_files_recursive(path)
				if path == "" then path = "." end

				if not path:sub(-1) ~= "/" then path = path .. "/" end

				local out = {}
				local errors = {}
				out[0] = 1

				if not walk(path, out, errors) then return nil, errors[1].error end

				out[0] = nil
				return out, errors[1] and errors or nil
			end
		end
	end

	function fs.get_current_directory()
		local buffer = ffi.new("char[260]")
		local length = ffi.C.GetCurrentDirectoryA(260, buffer)
		return ffi.string(buffer, length):gsub("\\", "/")
	end

	function fs.set_current_directory(path)
		if ffi.C.SetCurrentDirectoryA(path) == 0 then return nil, error_string() end

		return true
	end

	function fs.create_directory(path)
		if ffi.C.CreateDirectoryA(path, nil) == 0 then return nil, error_string() end

		return true
	end

	function fs.setcustomattribute(path, data)
		local f = io.open(path .. ":goluwa_attributes", "wb")

		if not f then return nil, err end

		f:write(data)
		f:close()
	end

	function fs.getcustomattribute(path)
		local f, err = io.open(path .. ":goluwa_attributes", "rb")

		if not f then return "" end

		local data = f:read("*all")
		f:close()
		return data
	end

	do
		local queue = {}

		function fs.watch(path, mask)
			local self = {}

			function self:Read() end

			function self:Remove() end

			return self
		end
	end

	function fs.link(from, to, symbolic)
		if ffi.C.CreateHardLinkA(to, from, nil) == 0 then
			return nil, error_string()
		end

		return true
	end

	function fs.copy(from, to)
		if ffi.C.CopyFileA(from, to, 1) == 0 then return nil, error_string() end

		return true
	end

	function fs.remove_file(path)
		if ffi.C.DeleteFileA(path) == 0 then return nil, error_string() end

		return true
	end

	function fs.remove_directory(path)
		if ffi.C.RemoveDirectoryA(path) == 0 then return nil, error_string() end

		return true
	end

	return fs
end

return fs