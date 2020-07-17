ffi.cdef[[SOCKET socket(int af, int type, int protocol);]]

local C = ffi.C
type C.socket = function(number, number, number): number


local fd = C.socket(0, 0, 0)