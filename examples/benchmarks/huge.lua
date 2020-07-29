if _G.ravi then
    _G.ravi.jit(true)
end

local oh = require("oh")
local util = require("oh.util")

util.LogTraceAbort()
util.EnhancedJITSettings()

local code = oh.Code(assert(util.FetchCode("examples/benchmarks/10mb.lua", "https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua")), "10mb.lua")

local start = os.clock()
local tokens = util.Measure("code:Lex()", function() return assert(code:Lex()).Tokens end)
local ast = util.Measure("code:Parse()", function() return assert(code:Parse()).SyntaxTree end)
local lua_code = util.Measure("code:BuildLua()", function() return assert(code:Emit()) end)
print("==========================================")
print((os.clock() - start) .. " seconds total")
print("==========================================")
io.write("parsed a total of ", #tokens, " tokens\n")
io.write("main block of tree contains ", #ast.statements, " statements\n")

local func = util.Measure("load(lua_code)", function() return assert(load(lua_code)) end)
local original_func = util.Measure("load huge code", function() return assert(load(code.code)) end)
io.write("size of original function in bytecode is ", #string.dump(original_func), " bytes\n")
io.write("size of function in bytecode is ", #string.dump(func), " bytes\n")