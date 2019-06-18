local oh = require("oh.oh")
local util = require("oh.util")

--[[
    jit.opt.start(
        "maxtrace=65535", -- 1000 1-65535: maximum number of traces in the cache
        "maxrecord=20000", -- 4000: maximum number of recorded IR instructions
        "maxirconst=500", -- 500: maximum number of IR constants of a trace
        "maxside=100", -- 100: maximum number of side traces of a root trace
        "maxsnap=800", -- 500: maximum number of snapshots for a trace
        "hotloop=56", -- 56: number of iterations to detect a hot loop or hot call
        "hotexit=10", -- 10: number of taken exits to start a side trace
        "tryside=4", -- 4: number of attempts to compile a side trace
        "instunroll=500", -- 4: maximum unroll factor for instable loops
        "loopunroll=500", -- 15: maximum unroll factor for loop ops in side traces
        "callunroll=500", -- 3: maximum unroll factor for pseudo-recursive calls
        "recunroll=2", -- 2: minimum unroll factor for true recursion
        "maxmcode=8192", -- 512: maximum total size of all machine code areas in KBytes
        --jit.os == "x64" and "sizemcode=64" or "sizemcode=32", -- Size of each machine code area in KBytes (Windows: 64K)
        "+fold", -- Constant Folding, Simplifications and Reassociation
        "+cse", -- Common-Subexpression Elimination
        "+dce", -- Dead-Code Elimination
        "+narrow", -- Narrowing of numbers to integers
        "+loop", -- Loop Optimizations (code hoisting)
        "+fwd", -- Load Forwarding (L2L) and Store Forwarding (S2L)
        "+dse", -- Dead-Store Elimination
        "+abc", -- Array Bounds Check Elimination
        "+sink", -- Allocation/Store Sinking
        "+fuse" -- Fusion of operands into instructions
    )]]

    --require("oh.util").LogTraceAbort()

local time
local function start(what)
    io.write("=========== " .. what .. " =============")
    time = os.clock()
    io.flush()
end

local function stop()
    io.write("- OK ", (os.clock() - time) .. " seconds\n")
end

local code = util.FetchCode("benchmarks/10mb.lua", "https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua")

start("loadstring huge code")
local func, err = loadstring(code)
stop()

if func then
    io.write("size of function in bytecode is ", #string.dump(func), " bytes\n")
else
    io.write(err)
end

start("utf8totable")
local tbl = require("oh.util").UTF8ToTable(code)
stop()

start("tokenizing")
local tokens, err = oh.CodeToTokens(tbl)
stop()
if tokens then
    io.write("parsed ", #tokens, " tokens\n")
else
    io.write(err)
end

start("parsing")
local ast, err = oh.TokensToAST(tokens, nil, tbl)
stop()
if ast then
    io.write("main block of tree contains ", #ast.statements, " statements\n")
else
    io.write(err)
end

start("generating lua code")
local code = oh.ASTToCode(ast)
stop()

start("loadstringing generated lua code")
local func, err = loadstring(code)
stop()

if func then
    io.write("size of function in bytecode is ", #string.dump(func), " bytes\n")
else
    io.write(err)
end