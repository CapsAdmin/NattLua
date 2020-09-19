--[[
    some lines before the code
]]

local a = 2 + 1
-- ERROR3
print(debug.traceback())
assert(loadfile("test/lua/analyzer/file_importing/deep_error/file_that_errors.oh"))()