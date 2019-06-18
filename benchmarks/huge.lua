local oh = require("oh.oh")

local huge = assert(io.open("benchmarks/10mb.lua", "rb")):read("*all")

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

local start = os.clock()
io.write("utf8totable ..")io.flush()
local tbl = require("oh.util").UTF8ToTable(code)
io.write("- OK ", (os.clock() - start) .. " seconds\n")

io.write("tokenizing ..")io.flush()
local start = os.clock()
local tokens, err = oh.CodeToTokens(tbl)
print(tokens, err)
io.write("- OK ", (os.clock() - start) .. " seconds\n")

io.write("parsing ..")io.flush()
local start = os.clock()
local ast, err = oh.TokensToAST(tokens, nil, tbl)
print(ast, err)
io.write("- OK ", (os.clock() - start) .. " seconds\n")

io.write("generating lua code ..")io.flush()
local start = os.clock()
local code = oh.ASTToCode(ast)
io.write("- OK ", (os.clock() - start) .. " seconds\n")

print(loadstring(code))