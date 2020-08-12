local oh = require("oh")
local LuaEmitter = require("oh.lua.javascript_emitter")
local code = io.open("oh/parser.lua"):read("*all")

code = [==[if --[[1]] true --[[2]]then
    print("foo")
elseif--[[3]] false and 1 --[[4]]then
    print("bar")
else --[[5]]
    print("faz")
end

for i = 1, 10 do 

end

for i = 1, 10, 2 do 
    print(i)
end

]==]

local ast = assert(oh.Code(code):Parse()).SyntaxTree

local em = LuaEmitter()

loadstring(code)()

local code = em:BuildCode(ast)
code = [[
    let print = console.log
]] .. code
print(code)

local f = io.open("temp.js", "wb")
f:write(code)
f:close()


os.execute("node temp.js")

os.remove("temp.js")