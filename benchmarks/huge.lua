if ravi then
    ravi.jit(true)
end

local oh = require("oh")
local util = require("oh.util")

--util.LogTraceAbort()
util.EnhancedJITSettings()

local code = assert(util.FetchCode("benchmarks/10mb.lua", "https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua"))

local start = os.clock()
local tokens = util.Measure("oh.CodeToTokens(code)", function() return assert(oh.CodeToTokens(code)) end)
local ast = util.Measure("oh.TokensToAST(tokens)", function() return assert(oh.TokensToAST(tokens, "benchmarks/10mb.lua", code)) end)
local lua_code = util.Measure("oh.ASTToCode(ast)", function() return assert(oh.ASTToCode(ast)) end)
print("==========================================")
print((os.clock() - start) .. " seconds total")
print("==========================================")
io.write("parsed a total of ", #tokens, " tokens\n")
io.write("main block of tree contains ", #ast.statements, " statements\n")

local func = util.Measure("loadstring(lua_code)", function() return assert(loadstring(lua_code)) end)
local original_func = util.Measure("loadstring huge code", function() return assert(loadstring(code)) end)
io.write("size of original function in bytecode is ", #string.dump(original_func), " bytes\n")
io.write("size of function in bytecode is ", #string.dump(func), " bytes\n")