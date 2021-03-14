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
IMPORTS['example_project/src/platforms/unix/filesystem.nlua'] = function(...) local ffi = require("ffi")
local OSX = ffi.os == "OSX"
local X64 = ffi.arch == "x64"
--[==[


-- helper type functions
local function List<|typ|>
	return {[number] = bit.bor( typ,  nil) }
end]==]
--[==[

local function ErrorReturn<|...|>
    return bit.bor( Tuple<|...|>,  Tuple<|nil, string|>) 
end]==]

local fs = {}

ffi.cdef([[
    const char *strerror(int);
    unsigned long syscall(int number, ...);
]])

local function last_error(num)
    num = num or ffi.errno()
    local ptr = ffi.C.strerror(num)
    if not ptr then
        return "strerror returns null"
    end
    local err = ffi.string(ptr)
    return err == "" and tostring(num) or err
end

do
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
    local stat
    local stat_link

    if OSX then
        ffi.cdef([[
            int stat64(const char *path, void *buf);
            int lstat64(const char *path, void *buf);
        ]])
        stat = ffi.C.stat64
        stat_link = ffi.C.lstat64
    else
        local STAT_SYSCALL = 195
        local STAT_LINK_SYSCALL = 196

        if X64 then
            STAT_SYSCALL = 4
            STAT_LINK_SYSCALL = 6
        end

        stat = function(path, buff)
            return ffi.C.syscall(STAT_SYSCALL, path, buff)
        end

        stat_link = function(path, buff)
            return ffi.C.syscall(STAT_LINK_SYSCALL, path, buff)
        end
    end

    local DIRECTORY = 0x4000

    function fs.get_attributes(path, follow_link)
		local buff = statbox()

		local ret = follow_link and stat_link(path, buff) or stat(path, buff)

		if ret == 0 then
			return {
				last_accessed = tonumber(buff[0].st_atime),
				last_changed = tonumber(buff[0].st_ctime),
				last_modified = tonumber(buff[0].st_mtime),
				size = tonumber(buff[0].st_size),

                type = bit.band(buff[0].st_mode, DIRECTORY) ~= 0 and "directory" or "file",
			}
		end

		return nil, last_error()
	end
end

do
    ffi.cdef[[
        void *opendir(const char *name);
        int closedir(void *dirp);
    ]] 

    if OSX then
        ffi.cdef([[
            struct dirent {
                uint64_t d_ino;
                uint64_t d_seekoff;
                uint16_t d_reclen;
                uint16_t d_namlen;
                uint8_t  d_type;
                char d_name[1024];
            };
            struct dirent *readdir(void *dirp) asm("readdir$INODE64");
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
            struct dirent *readdir(void *dirp) asm("readdir64");
        ]])
    end

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

    function fs.get_files(path)
        local out = {}

        local ptr = ffi.C.opendir(path or "")

        if ptr == nil then
            return nil, last_error()
        end

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
end

do
    ffi.cdef([[
        const char *getcwd(const char *buf, size_t size);
        int chdir(const char *filename);
    ]])

    function fs.set_current_directory(path)
		if ffi.C.chdir(path) == 0 then
            return true
		end
        
        return nil, last_error()
	end

	function fs.get_current_directory()
		local temp = ffi.new("char[1024]")
        local ret = ffi.C.getcwd(temp, ffi.sizeof(temp))
        
        if ret then
		    return ffi.string(ret, ffi.sizeof(temp))
        end

        return nil, last_error()
	end
end

return fs end
local fs =( IMPORTS['example_project/src/platforms/unix/filesystem.nlua']("platforms/unix/filesystem.nlua"))
--[==[

print<|fs|>]==] -- typesystem call, it won't be in build output

print("get files: ", assert(fs.get_files(".")))
for k,v in ipairs(assert(fs.get_files("."))) do print(k,v) end
print(assert(fs.get_current_directory()))

for k,v in pairs(assert(fs.get_attributes("README.md"))) do
    print(k,v)
end

