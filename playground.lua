io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
io.flush()
--if not ... then return end

local ffi = require("ffi")
ffi.cdef("int chdir(const char *filename); int usleep(unsigned int usec);")
ffi.C.chdir("/home/caps/oh/")

local json = require("vscode.server.json")

local a =  1