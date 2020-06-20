local util = {}

function util.FetchCode(path, url) --: type util.FetchCode = function(string, string): string
    local f = io.open(path, "rb")
    if not f then
        os.execute("wget -O "..path.." " .. url)
        f = io.open(path, "rb")
        if not f then
            os.execute("curl "..url.." --output " .. path)
        end
        if not io.open(path, "rb") then
            error("unable to download file?")
        end
    end

    f = assert(io.open(path, "rb"))
    local code = f:read("*all")
    f:close()
    return code
end

do
    local indent = 0
	local function dump(tbl, blacklist, done)
		for k,v in pairs(tbl) do
			if (not blacklist or blacklist[k] ~= type(v)) and type(v) ~= "table" then
				io.write(("\t"):rep(indent))
				local v = v
				if type(v) == "string" then
					v = "\"" .. v .. "\""
				end

				io.write(tostring(k), " = ", tostring(v), "\n")
			end
		end

		for k,v in pairs(tbl) do
            if (not blacklist or blacklist[k] ~= type(v)) and type(v) == "table" then
                if done[v] then
                    io.write(("\t"):rep(indent))
                    io.write(tostring(k), ": CIRCULAR\n")
                else
                    io.write(("\t"):rep(indent))
                    io.write(tostring(k), ":\n")
                    indent = indent + 1
                    done[v] = true
                    dump(v, blacklist, done)
                    indent = indent - 1
                end
			end
		end
    end

    function util.TablePrint(tbl, blacklist)
        dump(tbl, blacklist, {})
    end
end

function util.CountFields(tbl, what, cb, max)
    max = max or 10

    local score = {}
    for _,v in ipairs(tbl) do
        local key = cb(v)
        score[key] = (score[key] or 0) + 1
    end
    local temp = {}
    for k,v in pairs(score) do
        table.insert(temp, {name = k, score = v})
    end
    table.sort(temp, function(a,b) return a.score > b.score end)
    io.write("top "..max.." ",what,":\n")
    for i = 1, max do
        local data = temp[i]
        if not data then break end
        if i < max then io.write(" ") end
        io.write(i, ": `", data.name, "´ occured ", data.score, " times\n")
    end
end

function util.LogTraceAbort()
    local vmdef = {
        bcnames = "ISLT  ISGE  ISLE  ISGT  ISEQV ISNEV ISEQS ISNES ISEQN ISNEN ISEQP ISNEP ISTC  ISFC  IST   ISF   ISTYPEISNUM MOV   NOT   UNM   LEN   ADDVN SUBVN MULVN DIVVN MODVN ADDNV SUBNV MULNV DIVNV MODNV ADDVV SUBVV MULVV DIVVV MODVV POW   CAT   KSTR  KCDATAKSHORTKNUM  KPRI  KNIL  UGET  USETV USETS USETN USETP UCLO  FNEW  TNEW  TDUP  GGET  GSET  TGETV TGETS TGETB TGETR TSETV TSETS TSETB TSETM TSETR CALLM CALL  CALLMTCALLT ITERC ITERN VARG  ISNEXTRETM  RET   RET0  RET1  FORI  JFORI FORL  IFORL JFORL ITERL IITERLJITERLLOOP  ILOOP JLOOP JMP   FUNCF IFUNCFJFUNCFFUNCV IFUNCVJFUNCVFUNCC FUNCCW",
        traceerr = {
            [0]="error thrown or hook called during recording",
            "trace too short",
            "trace too long",
            "trace too deep",
            "too many snapshots",
            "blacklisted",
            "retry recording",
            "NYI: bytecode %d",
            "leaving loop in root trace",
            "inner loop in root trace",
            "loop unroll limit reached",
            "bad argument type",
            "JIT compilation disabled for function",
            "call unroll limit reached",
            "down-recursion, restarting",
            "NYI: unsupported variant of FastFunc %s",
            "NYI: return to lower frame",
            "store with nil or NaN key",
            "missing metamethod",
            "looping index lookup",
            "NYI: mixed sparse/dense table",
            "symbol not in cache",
            "NYI: unsupported C type conversion",
            "NYI: unsupported C function type",
            "guard would always fail",
            "too many PHIs",
            "persistent type instability",
            "failed to allocate mcode memory",
            "machine code too long",
            "hit mcode limit (retrying)",
            "too many spill slots",
            "inconsistent register allocation",
            "NYI: cannot assemble IR instruction %d",
            "NYI: PHI shuffling too complex",
            "NYI: register coalescing too complex",
        },
    }
    local blacklist = {
        ["leaving loop in root trace"] = true,
        ["error thrown or hook fed during recording"] = true,
        ["down-recursion, restarting"] = true,
        ["loop unroll limit reached"] = true,
        ["inner loop in root trace"] = true,
    }

    jit.attach(function(what, trace_id, func, pc, trace_error_id, trace_error_arg)
        if what ~= "abort" then return end

        local reason = vmdef.traceerr[trace_error_id]

        if reason and not blacklist[reason] then
            local info = require("jit.util").funcinfo(func, pc)
            if type(trace_error_arg) == "number" and reason:find("bytecode") then
                trace_error_arg = string.sub(vmdef.bcnames, trace_error_arg*6+1, trace_error_arg*6+6)
                reason = reason:gsub("(%%d)", "%%s")
            end

            reason = reason:format(trace_error_arg)

            local path = info.source:sub(2)
            local line = info.currentline or info.linedefined

            io.write(path .. ":" .. line .. " - " .. reason .. "\n")
        end

    end, "trace")
end

function util.Measure(what, cb) -- type util.Measure = function(string, function): any
    if jit then
        jit.flush()
    end
    io.write("> ", what)
    local time = os.clock()
    io.flush()

    local ok, err = pcall(cb)

    if ok then
        io.write((" "):rep(40 - #what)," - OK ", (os.clock() - time) .. " seconds\n")
        return err
    else
        io.write(" - FAIL: ", err)
        error(err, 2)
    end
end

function util.EnhancedJITSettings()
    if not jit then return end
    jit.opt.start(
		"maxtrace=65535", -- 1000 1-65535: maximum number of traces in the cache
		"maxrecord=16000", -- 4000: maximum number of recorded IR instructions
		"maxirconst=500", -- 500: maximum number of IR constants of a trace
		"maxside=100", -- 100: maximum number of side traces of a root trace
		"maxsnap=500", -- 500: maximum number of snapshots for a trace
		"hotloop=56", -- 56: number of iterations to detect a hot loop or hot call
		"hotexit=10", -- 10: number of taken exits to start a side trace
		"tryside=8", -- 4: number of attempts to compile a side trace
		"instunroll=4", -- 4: maximum unroll factor for instable loops
		"loopunroll=15", -- 15: maximum unroll factor for loop ops in side traces
		"callunroll=3", -- 3: maximum unroll factor for pseudo-recursive calls
		"recunroll=0", -- 2: minimum unroll factor for true recursion
		"maxmcode=40960", -- 512: maximum total size of all machine code areas in KBytes
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
	)
	if jit.version_num >= 20100 then
		jit.opt.start("minstitch=3") -- 0: minimum number of IR ins for a stitched trace.
	end
end

return util