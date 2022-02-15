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
		for k, v in pairs(tbl) do
			out[k] = v
		end
	end

	return out
end

function table.spread(tbl)
	if not tbl then return nil end
	return table.unpack(tbl)
end

function LSX(tag, constructor, props, children)
	local e = constructor and
		constructor(props, children) or
		{props = props, children = children,}
	e.tag = tag
	return e
end

local table_print = require("nattlua.other.table_print")

function table.print(...)
	return table_print(...)
end

IMPORTS = IMPORTS or {}
IMPORTS['example_projects/luajit/src/platforms/windows/filesystem.nlua'] = function(...) --[[#local  type  contract  =  import_type<|"platforms/filesystem.nlua"|>]]


local  ffi--[[#: {
	"errno" = function⦗nil | number⦘: ⦗number⦘,
	"os" = "BSD" | "Linux" | "OSX" | "Other" | "POSIX" | "Windows",
	"arch" = "arm" | "mips" | "ppc" | "ppcspe" | "x64" | "x86",
	"C" = FFI_C,
	"cdef" = function⦗string, any⦘: ⦗⦘,
	"abi" = function⦗string⦘: ⦗false | true⦘,
	"metatype" = function⦗any, any⦘: ⦗⦘,
	"new" = function⦗any, ⦗any⦘×inf⦘: ⦗⦘,
	"copy" = function⦗any, any, nil | number⦘: ⦗nil⦘,
	"alignof" = function⦗any⦘: ⦗number⦘,
	"cast" = function⦗string, any⦘: ⦗⦘,
	"typeof" = function⦗string, any⦘: ⦗⦘,
	"load" = function⦗string⦘: ⦗⦘,
	"sizeof" = function⦗any, number⦘: ⦗number⦘ | function⦗any⦘: ⦗number⦘,
	"string" = function⦗{ number = any }, nil | number⦘: ⦗string⦘,
	"gc" = function⦗any, function⦗⦗any⦘×inf⦘: ⦗⦗any⦘×inf⦘⦘: ⦗⦘,
	"istype" = function⦗any, any⦘: ⦗false | true⦘,
	"fill" = function⦗{ number = any }, number, any⦘: ⦗nil⦘ | function⦗{ number = any }, number⦘: ⦗nil⦘,
	"offsetof" = function⦗{ number = any }, number⦘: ⦗number⦘,
	"get_type" = function⦗string, nil | { string = any }⦘: ⦗⦘
}]]  =  require("ffi")

local  OSX--[[#: false | true]]  =  ffi.os  ==  "OSX"

local  X64--[[#: false | true]]  =  ffi.arch  ==  "x64"


local  fs--[[#: {
	"get_attributes" = function⦗string, false | nil | true⦘: ⦗⦗nil, string⦘ | ⦗{
		"last_accessed" = number,
		"last_changed" = number,
		"last_modified" = number,
		"size" = number,
		"type" = "directory" | "file"
	}⦘⦘,
	"get_files" = function⦗string⦘: ⦗⦗nil, string⦘ | ⦗{ number = nil | string }⦘⦘,
	"set_current_directory" = function⦗string⦘: ⦗⦗nil, string⦘ | ⦗true⦘⦘,
	"get_current_directory" = function⦗⦘: ⦗⦗nil, string⦘ | ⦗string⦘⦘
}]]  =  {}--[[#  as  contract]]


ffi.cdef(
	[[
	uint32_t GetLastError();
    uint32_t FormatMessageA(
		uint32_t dwFlags,
		const void* lpSource,
		uint32_t dwMessageId,
		uint32_t dwLanguageId,
		char* lpBuffer,
		uint32_t nSize,
		...
	);
]]
)



local  function  last_error()--[[#:  string]]
	
    local  error_str--[[#: { number = number }]]  =  ffi.new("uint8_t[?]",  1024)
	
    local  FORMAT_MESSAGE_FROM_SYSTEM--[[#: 4096]]  =  0x00001000
	
    local  FORMAT_MESSAGE_IGNORE_INSERTS--[[#: 512]]  =  0x00000200
	
    local  error_flags--[[#: 4608]]  =  bit.bor(FORMAT_MESSAGE_FROM_SYSTEM,  FORMAT_MESSAGE_IGNORE_INSERTS)
	

    local  code--[[#: number]]  =  ffi.C.GetLastError()
	
	local  numout--[[#: number]]  =  ffi.C.FormatMessageA(error_flags,  nil,  code,  0,  error_str,  1023,  nil)

	
	
    if  numout  ~=  0  then
		
        local  err--[[#: string]]  =  ffi.string(error_str,  numout)
		
        if  err:sub(-2)  ==  "\r\n"  then 
            return  err:sub(0,  -3) 
        end
	
    end

	

	return  "no error"

end



do
	
    local  struct--[[#: {
	"dwFileAttributes" = number,
	"ftCreationTime" = number,
	"ftLastAccessTime" = number,
	"ftLastWriteTime" = number,
	"nFileSize" = number,
	"__call" = function⦗*self-table*, nil | {
		"dwFileAttributes" = nil | number,
		"ftCreationTime" = nil | number,
		"ftLastAccessTime" = nil | number,
		"ftLastWriteTime" = nil | number,
		"nFileSize" = nil | number
	}⦘: ⦗*self-table*⦘
}]]  =  ffi.typeof(
			[[
        struct {
            unsigned long dwFileAttributes;
            uint64_t ftCreationTime;
            uint64_t ftLastAccessTime;
            uint64_t ftLastWriteTime;
            uint64_t nFileSize;
        }
    ]]
		)
	

	ffi.cdef(
		[[
        int GetFileAttributesExA(const char *lpFileName, int fInfoLevelId, $ *lpFileInformation);
    ]],  struct
	)

	

    local  function  POSIX_TIME(time--[[#:  number]]--[[#:  number]])
		
        return  tonumber(time  /  10000000  -  11644473600)
	
    end

	

    local  flags--[[#: {
	"archive" = 32,
	"compressed" = 2048,
	"device" = 64,
	"directory" = 16,
	"encrypted" = 16384,
	"hidden" = 2,
	"integrity_stream" = 32768,
	"normal" = 128,
	"not_content_indexed" = 8192,
	"no_scrub_data" = 131072,
	"offline" = 4096,
	"readonly" = 1,
	"reparse_point" = 1024,
	"sparse_file" = 512,
	"system" = 4,
	"temporary" = 256,
	"virtual" = 65536
}]]  =  {
		
        archive  =  0x20,
		 -- A file or directory that is an archive file or directory. Applications typically use this attribute to mark files for backup or removal .
		
        compressed  =  0x800,
		 -- A file or directory that is compressed. For a file, all of the data in the file is compressed. For a directory, compression is the default for newly created files and subdirectories.
		
        device  =  0x40,
		 -- This value is reserved for system use.
		
        directory  =  0x10,
		 -- The handle that identifies a directory.
		
        encrypted  =  0x4000,
		 -- A file or directory that is encrypted. For a file, all data streams in the file are encrypted. For a directory, encryption is the default for newly created files and subdirectories.
		
        hidden  =  0x2,
		 -- The file or directory is hidden. It is not included in an ordinary directory listing.
		
        integrity_stream  =  0x8000,
		 -- The directory or user data stream is configured with integrity (only supported on ReFS volumes). It is not included in an ordinary directory listing. The integrity setting persists with the file if it's renamed. If a file is copied the destination file will have integrity set if either the source file or destination directory have integrity set.
		
        normal  =  0x80,
		 -- A file that does not have other attributes set. This attribute is valid only when used alone.
		
        not_content_indexed  =  0x2000,
		 -- The file or directory is not to be indexed by the content indexing service.
		
        no_scrub_data  =  0x20000,
		 -- The user data stream not to be read by the background data integrity scanner (AKA scrubber). When set on a directory it only provides inheritance. This flag is only supported on Storage Spaces and ReFS volumes. It is not included in an ordinary directory listing.
		
        offline  =  0x1000,
		 -- The data of a file is not available immediately. This attribute indicates that the file data is physically moved to offline storage. This attribute is used by Remote Storage, which is the hierarchical storage management software. Applications should not arbitrarily change this attribute.
		
        readonly  =  0x1,
		 -- A file that is read-only. Applications can read the file, but cannot write to it or delete it. This attribute is not honored on directories. For more information, see You cannot view or change the Read-only or the System attributes of folders in Windows Server 2003, in Windows XP, in Windows Vista or in Windows 7.
		
        reparse_point  =  0x400,
		 -- A file or directory that has an associated reparse point, or a file that is a symbolic link.
		
        sparse_file  =  0x200,
		 -- A file that is a sparse file.
		
        system  =  0x4,
		 -- A file or directory that the operating system uses a part of, or uses exclusively.
		
        temporary  =  0x100,
		 -- A file that is being used for temporary storage. File systems avoid writing data back to mass storage if sufficient cache memory is available, because typically, an application deletes a temporary file after the handle is closed. In that scenario, the system can entirely avoid writing the data. Otherwise, the data is written after the handle is closed.
		
        virtual  =  0x10000,
 -- This value is reserved for system use.
		
    }

	

	function  fs.get_attributes(path--[[#: string]],  follow_link--[[#: false | nil | true]])
		
        local  info--[[#: { number = {
		"dwFileAttributes" = number,
		"ftCreationTime" = number,
		"ftLastAccessTime" = number,
		"ftLastWriteTime" = number,
		"nFileSize" = number,
		"__call" = function⦗*self-table*, nil | {
			"dwFileAttributes" = nil | number,
			"ftCreationTime" = nil | number,
			"ftLastAccessTime" = nil | number,
			"ftLastWriteTime" = nil | number,
			"nFileSize" = nil | number
		}⦘: ⦗*self-table*⦘
	} }]]  =  ffi.new("$[1]",  struct)
		

        if  ffi.C.GetFileAttributesExA(path,  0,  info)  ~=  0  then 
            return  {
			
                creation_time  =  POSIX_TIME(info[0].ftCreationTime),
			
                last_accessed  =  POSIX_TIME(info[0].ftLastAccessTime),
			
                last_modified  =  POSIX_TIME(info[0].ftLastWriteTime),
			
                last_changed  =  -1,
			 -- last permission changes
			
                size  =  tonumber(info[0].nFileSize),
			
                type  =  bit.band(
                    info[0].dwFileAttributes,  flags.directory
                )  ==  flags.directory  and  "directory"  or  "file",

            } 
        end
		

		return  nil,  last_error()
	
	end

end



do
	
    local  struct--[[#: {
	"dwFileAttributes" = number,
	"ftCreationTime" = number,
	"ftLastAccessTime" = number,
	"ftLastWriteTime" = number,
	"nFileSize" = number,
	"dwReserved" = number,
	"cFileName" = { number = number },
	"cAlternateFileName" = { number = number },
	"__call" = function⦗*self-table*, nil | {
		"dwFileAttributes" = nil | number,
		"ftCreationTime" = nil | number,
		"ftLastAccessTime" = nil | number,
		"ftLastWriteTime" = nil | number,
		"nFileSize" = nil | number,
		"dwReserved" = nil | number,
		"cFileName" = nil | { number = number },
		"cAlternateFileName" = nil | { number = number }
	}⦘: ⦗*self-table*⦘
}]]  =  ffi.typeof(
			[[
        struct {
            uint32_t dwFileAttributes;

            uint64_t ftCreationTime;
            uint64_t ftLastAccessTime;
            uint64_t ftLastWriteTime;

            uint64_t nFileSize;
            
            uint64_t dwReserved;
        
            char cFileName[260];
            char cAlternateFileName[14];
        }
    ]]
		)
	

	ffi.cdef(
		[[
        void *FindFirstFileA(const char *lpFileName, $ *find_data);
        int FindNextFileA(void *handle, $ *find_data);
        int FindClose(void *);
	]],  struct,  struct
	)
	

	local  dot--[[#: 46]]  =  string.byte(".")

	
	local  function  is_dots(ptr--[[#:  {[number]  =  number}]]--[[#:  {[number]  =  number}]])
		
		if  ptr[0]  ==  dot  then
			
			if  ptr[1]  ==  dot  and  ptr[2]  ==  0  then 
				return  true 
			end
			
			if  ptr[1]  ==  0  then 
				return  true 
			end
		
		end

		

		return  false
	
	end

	
    
    local  INVALID_FILE--[[#: any]]  =  ffi.cast("void *",  0xFFFFFFFFFFFFFFFFULL)

	

	function  fs.get_files(path--[[#: string]])
		
		if  path  ==  ""  then
			
            path  =  "."
		
        end

		
        
        if  path:sub(-1)  ~=  "/"  then
			
            path  =  path  ..  "/"
		
        end

		

        local  data--[[#: { number = {
		"dwFileAttributes" = number,
		"ftCreationTime" = number,
		"ftLastAccessTime" = number,
		"ftLastWriteTime" = number,
		"nFileSize" = number,
		"dwReserved" = number,
		"cFileName" = { number = number },
		"cAlternateFileName" = { number = number },
		"__call" = function⦗*self-table*, nil | {
			"dwFileAttributes" = nil | number,
			"ftCreationTime" = nil | number,
			"ftLastAccessTime" = nil | number,
			"ftLastWriteTime" = nil | number,
			"nFileSize" = nil | number,
			"dwReserved" = nil | number,
			"cFileName" = nil | { number = number },
			"cAlternateFileName" = nil | { number = number }
		}⦘: ⦗*self-table*⦘
	} }]]  =  ffi.new("$[1]",  struct)
		
        local  handle--[[#: any]]  =  ffi.C.FindFirstFileA(path  ..  "*",  data)
		

        if  handle  ==  nil  then 
            return  nil,  last_error() 
        end
		

        local  out--[[#: { 1 = string }]]  =  {}
		

        if  handle  ==  INVALID_FILE  then 
            return  out 
        end
		

        local  i--[[#: 1]]  =  1

		
        repeat
			
            if  not  is_dots(data[0].cFileName)  then
				
                out[i]  =  ffi.string(data[0].cFileName)
				
                i  =  i  +  1
			
            end		
        until  ffi.C.FindNextFileA(handle,  data)  ==  0

		

        if  ffi.C.FindClose(handle)  ==  0  then 
            return  nil,  last_error() 
        end
		

        return  out
	
	end

end



do
	
	ffi.cdef(
		[[
        unsigned long GetCurrentDirectoryA(unsigned long length, char *buffer);
        int SetCurrentDirectoryA(const char *path);
	]]
	)

	

	function  fs.set_current_directory(path--[[#: string]])
		
		if  ffi.C.chdir(path)  ==  0  then 
			return  true 
		end
		
		
		return  nil,  last_error()
	
	end

	

	function  fs.get_current_directory()
		
        local  buffer--[[#: { number = number }]]  =  ffi.new("char[260]")
		
        local  length--[[#: number]]  =  ffi.C.GetCurrentDirectoryA(260,  buffer)
		
        local  str--[[#: string]]  =  ffi.string(buffer,  length)
		
        return  (
				str:gsub("\\",  "/")
			)
	
	end

end



return  fs end
IMPORTS['example_projects/luajit/src/platforms/unix/filesystem.nlua'] = function(...) --[[#local  type  contract  =  import_type<|"platforms/filesystem.nlua"|>]]


local  ffi--[[#: {
	"errno" = function⦗nil | number⦘: ⦗number⦘,
	"os" = "BSD" | "Linux" | "OSX" | "Other" | "POSIX" | "Windows",
	"arch" = "arm" | "mips" | "ppc" | "ppcspe" | "x64" | "x86",
	"C" = FFI_C,
	"cdef" = function⦗string, any⦘: ⦗⦘,
	"abi" = function⦗string⦘: ⦗false | true⦘,
	"metatype" = function⦗any, any⦘: ⦗⦘,
	"new" = function⦗any, ⦗any⦘×inf⦘: ⦗⦘,
	"copy" = function⦗any, any, nil | number⦘: ⦗nil⦘,
	"alignof" = function⦗any⦘: ⦗number⦘,
	"cast" = function⦗string, any⦘: ⦗⦘,
	"typeof" = function⦗string, any⦘: ⦗⦘,
	"load" = function⦗string⦘: ⦗⦘,
	"sizeof" = function⦗any, number⦘: ⦗number⦘ | function⦗any⦘: ⦗number⦘,
	"string" = function⦗{ number = any }, nil | number⦘: ⦗string⦘,
	"gc" = function⦗any, function⦗⦗any⦘×inf⦘: ⦗⦗any⦘×inf⦘⦘: ⦗⦘,
	"istype" = function⦗any, any⦘: ⦗false | true⦘,
	"fill" = function⦗{ number = any }, number, any⦘: ⦗nil⦘ | function⦗{ number = any }, number⦘: ⦗nil⦘,
	"offsetof" = function⦗{ number = any }, number⦘: ⦗number⦘,
	"get_type" = function⦗string, nil | { string = any }⦘: ⦗⦘
}]]  =  require("ffi")

local  OSX--[[#: false | true]]  =  ffi.os  ==  "OSX"

local  X64--[[#: false | true]]  =  ffi.arch  ==  "x64"


local  fs--[[#: {
	"get_attributes" = function⦗string, false | nil | true⦘: ⦗⦗nil, string⦘ | ⦗{
		"last_accessed" = number,
		"last_changed" = number,
		"last_modified" = number,
		"size" = number,
		"type" = "directory" | "file"
	}⦘⦘,
	"get_files" = function⦗string⦘: ⦗⦗nil, string⦘ | ⦗{ number = nil | string }⦘⦘,
	"set_current_directory" = function⦗string⦘: ⦗⦗nil, string⦘ | ⦗true⦘⦘,
	"get_current_directory" = function⦗⦘: ⦗⦗nil, string⦘ | ⦗string⦘⦘
}]]  =  {}--[[#  as  contract]]


ffi.cdef([[
	const char *strerror(int);
	unsigned long syscall(int number, ...);
]])



local  function  last_error(num--[[#:  number  |  nil]]--[[#:  number  |  nil]])
	
	num  =  num  or  ffi.errno()
	
	local  ptr--[[#: nil | { number = number }]]  =  ffi.C.strerror(num)
	
	if  not  ptr  then 
		return  "strerror returns null" 
	end
	
	local  err--[[#: string]]  =  ffi.string(ptr)
	
	return  err  ==  ""  and  tostring(num)  or  err

end



do
	
	local  stat_struct--[[#: nil]]

	

	if  OSX  then
		
		stat_struct  =  ffi.typeof(
				[[
			struct {
				uint32_t st_dev;
				uint16_t st_mode;
				uint16_t st_nlink;
				uint64_t st_ino;
				uint32_t st_uid;
				uint32_t st_gid;
				uint32_t st_rdev;
				size_t   st_atime;
				long     st_atime_nsec;
				size_t   st_mtime;
				long     st_mtime_nsec;
				size_t   st_ctime;
				long     st_ctime_nsec;
				size_t   st_btime;
				long     st_btime_nsec;
				int64_t  st_size;
				int64_t  st_blocks;
				int32_t  st_blksize;
				uint32_t st_flags;
				uint32_t st_gen;
				int32_t  st_lspare;
				int64_t  st_qspare[2];
			}
		]]
			)
--[[#		

		type  stat_struct.@Name  =  "OSXStat"]]
	
	else
		
		if  X64  then
			
			stat_struct  =  ffi.typeof(
					[[
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
			]]
				)
--[[#			

			type  stat_struct.@Name  =  "UnixX64Stat"]]
		
		else
			
			stat_struct  =  ffi.typeof(
					[[
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
			]]
				)
--[[#			

			type  stat_struct.@Name  =  "UnixX32Stat"]]
		
		end
	
	end

	

	local  statbox--[[#: {
	number = OSXStat | UnixX32Stat | UnixX64Stat,
	"__call" = function⦗*self-table*, nil | { number = OSXStat | UnixX32Stat | UnixX64Stat | nil as OSXStat | UnixX32Stat | UnixX64Stat, [nil as "__call"] = nil as function*self-tuple*: ⦗*self-table*⦘ }⦘: ⦗*self-table*⦘
}]]  =  ffi.typeof("$[1]",  stat_struct)
	
	local  stat--[[#: nil]]
	
	local  stat_link--[[#: nil]]

	

	if  OSX  then
		
		ffi.cdef(
			[[
			int stat64(const char *path, void *buf);
			int lstat64(const char *path, void *buf);
		]]
		)
		
		stat  =  ffi.C.stat64
		
		stat_link  =  ffi.C.lstat64
	
	else
		
		local  STAT_SYSCALL--[[#: 195]]  =  195
		
		local  STAT_LINK_SYSCALL--[[#: 196]]  =  196

		

		if  X64  then
			
			STAT_SYSCALL  =  4
			
			STAT_LINK_SYSCALL  =  6
		
		end

		

		stat  =  function(path--[[#:  string]]--[[#:  string]],  buff--[[#:  typeof  statbox]]--[[#:  typeof  statbox]])
				
			return  ffi.C.syscall(STAT_SYSCALL,  path,  buff)
			
		end
		

		stat_link  =  function(path--[[#:  string]]--[[#:  string]],  buff--[[#:  typeof  statbox]]--[[#:  typeof  statbox]])
				
			return  ffi.C.syscall(STAT_LINK_SYSCALL,  path,  buff)
			
		end
	
	end

	

	local  DIRECTORY--[[#: 16384]]  =  0x4000

	

	function  fs.get_attributes(path--[[#: string]],  follow_link--[[#: false | nil | true]])
		
		local  buff--[[#: {
	number = OSXStat | UnixX32Stat | UnixX64Stat,
	"__call" = function⦗*self-table*, nil | { number = OSXStat | UnixX32Stat | UnixX64Stat | nil as OSXStat | UnixX32Stat | UnixX64Stat, [nil as "__call"] = nil as function*self-tuple*: ⦗*self-table*⦘ }⦘: ⦗*self-table*⦘
}]]  =  statbox()
		

		local  ret--[[#: number]]  =  follow_link  and  stat_link(path,  buff)  or  stat(path,  buff)
		

		if  ret  ==  0  then 
			return  {
			
				last_accessed  =  tonumber(buff[0].st_atime),
			
				last_changed  =  tonumber(buff[0].st_ctime),
			
				last_modified  =  tonumber(buff[0].st_mtime),
			
				size  =  tonumber(buff[0].st_size),
			

				type  =  bit.band(buff[0].st_mode,  DIRECTORY)  ~=  0  and  "directory"  or  "file",

			} 
		end
		

		return  nil,  last_error()
	
	end

end



do
	
	ffi.cdef([[
		void *opendir(const char *name);
		int closedir(void *dirp);
	]])

	 

	if  OSX  then
		
		ffi.cdef(
			[[
			struct dirent {
				uint64_t d_ino;
				uint64_t d_seekoff;
				uint16_t d_reclen;
				uint16_t d_namlen;
				uint8_t  d_type;
				char d_name[1024];
			};
			struct dirent *readdir(void *dirp) asm("readdir$INODE64");
		]]
		)
	
	else
		
		ffi.cdef(
			[[
			struct dirent {
				uint64_t        d_ino;
				int64_t         d_off;
				unsigned short  d_reclen;
				unsigned char   d_type;
				char            d_name[256];
			};
			struct dirent *readdir(void *dirp) asm("readdir64");
		]]
		)
	
	end

	

	local  dot--[[#: 46]]  =  string.byte(".")

	
	local  function  is_dots(ptr--[[#:  {[number]  =  number}]]--[[#:  {[number]  =  number}]])
		
		if  ptr[0]  ==  dot  then
			
			if  ptr[1]  ==  dot  and  ptr[2]  ==  0  then 
				return  true 
			end
			
			if  ptr[1]  ==  0  then 
				return  true 
			end
		
		end

		

		return  false
	
	end

	

	function  fs.get_files(path--[[#: string]])
		
		local  out--[[#:  List<|string|>]]--[[#:  List<|string|>]]  =  {}
		 -- [1] TODO
		

		local  ptr--[[#: any]]  =  ffi.C.opendir(path  or  "")
		

		if  ptr  ==  nil  then 
			return  nil,  last_error() 
		end
		

		local  i--[[#: 1]]  =  1

		
		while  true  do
			
			local  dir_info--[[#: nil | struct dirent*]]  =  ffi.C.readdir(ptr)
			

			dir_info  =  dir_info--[[#  as  dir_info  |  nil]]
			 -- TODO
			

			if  dir_info  ==  nil  then  break  end

			

			if  not  is_dots(dir_info.d_name)  then
				
				out[i]  =  ffi.string(dir_info.d_name)
				
				i  =  i  +  1
			
			end
		
		end

		

		ffi.C.closedir(ptr)
		
		
		return  out
	
	end

end



do
	
	ffi.cdef(
		[[
		const char *getcwd(const char *buf, size_t size);
		int chdir(const char *filename);
	]]
	)

	

	function  fs.set_current_directory(path--[[#: string]])
		
		if  ffi.C.chdir(path)  ==  0  then 
			return  true 
		end
		
		
		return  nil,  last_error()
	
	end

	

	function  fs.get_current_directory()
		
		local  temp--[[#: { number = number }]]  =  ffi.new("char[1024]")
		
		local  ret--[[#: nil | { number = number }]]  =  ffi.C.getcwd(temp,  ffi.sizeof(temp))
		
		
		if  ret  then 
			return  ffi.string(ret,  ffi.sizeof(temp)) 
		end
		
		
		return  nil,  last_error()
	
	end

end



return  fs end
IMPORTS['example_projects/luajit/src/filesystem.nlua'] = function(...) if  jit.os  ==  "Windows"  then
	
  return (
			 IMPORTS['example_projects/luajit/src/platforms/windows/filesystem.nlua']("platforms/windows/filesystem.nlua")
		)

else
	
  return (
			 IMPORTS['example_projects/luajit/src/platforms/unix/filesystem.nlua']("platforms/unix/filesystem.nlua")
		)

end



error("unknown platform") end
local  fs--[[#: {
	"get_attributes" = function⦗string, false | nil | true⦘: ⦗⦗nil, string⦘ | ⦗{
		"last_accessed" = number,
		"last_changed" = number,
		"last_modified" = number,
		"size" = number,
		"type" = "directory" | "file"
	}⦘⦘,
	"get_files" = function⦗string⦘: ⦗⦗nil, string⦘ | ⦗{ number = nil | string }⦘⦘,
	"set_current_directory" = function⦗string⦘: ⦗⦗nil, string⦘ | ⦗true⦘⦘,
	"get_current_directory" = function⦗⦘: ⦗⦗nil, string⦘ | ⦗string⦘⦘
}]]  = (
		 IMPORTS['example_projects/luajit/src/filesystem.nlua']("filesystem.nlua")
	)


print("get files: ",  assert(fs.get_files(".")))


for  k, v  in  ipairs(assert(fs.get_files(".")))  do
	 print(k, v)
 end


print(assert(fs.get_current_directory()))



for  k, v  in  pairs(assert(fs.get_attributes("README.md")))  do
	
    print(k, v)

end

