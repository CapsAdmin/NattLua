local oh = require("oh")
local path = arg[1]
local c = oh.File(path, {annotate = true})
local ok, err = c:Analyze()
if not ok then
    print(err)
    return
end
local res = assert(c:BuildLua())
require("oh.lua.base_runtime")
print(res)