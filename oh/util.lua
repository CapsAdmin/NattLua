local util = {}

do
    local map = {}
    for byte = 0, 255 do
        local length =
            byte>=240 and 4 or
            byte>=223 and 3 or
            byte>=192 and 2 or
            1
        map[byte] = length
    end

    function util.UTF8ToTable(str)
        local tbl = {}
        local i = 1
        local length = 1

        for tbl_i = 1, #str do
            local length = map[str:byte(i)]

            if not length then break end

            tbl[tbl_i] = str:sub(i, i + length - 1)
            i = i + length
        end

        return tbl
    end
end

function util.fetch_code(path, url)
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
        ["too many spill slots"] = true,
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

            print(path .. ":" .. line .. " - " .. reason)
        end

    end, "trace")
end

return util