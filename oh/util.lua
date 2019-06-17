local util = {}

do
    -- http://bjoern.hoehrmann.de/utf-8/decoder/dfa/
    -- https://williamaadams.wordpress.com/2012/06/16/messing-around-with-utf-8-in-luajit/

    -- just without codepoints

    local utf8d = {
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, -- 00..1f
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, -- 20..3f
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, -- 40..5f
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, -- 60..7f
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, -- 80..9f
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, -- a0..bf
        8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, -- c0..df
        0xa,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x4,0x3,0x3, -- e0..ef
        0xb,0x6,0x6,0x6,0x5,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8, -- f0..ff
        0x0,0x1,0x2,0x3,0x5,0x8,0x7,0x1,0x1,0x1,0x4,0x6,0x1,0x1,0x1,0x1, -- s0..s0
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1, -- s1..s2
        1,2,1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1, -- s3..s4
        1,2,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,3,1,1,1,1,1,1, -- s5..s6
        1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1, -- s7..s8
    }

    function util.UTF8ToTable(str)
        local out = {}
        local out_i = 1

        local last_pos = 1

        local state = 0

        for i = 1, #str do
            state = utf8d[256 + state*16 + utf8d[str:byte(i)]]

            if state == 0 then
                out[out_i] = str:sub(last_pos, i)
                out_i = out_i + 1
                last_pos = i + 1
            end
        end

        return out
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