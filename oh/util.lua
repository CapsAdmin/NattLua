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
        str = util.RemoveBOMHeader(str)

        local tbl = {}
        local i = 1
        local length = 1

        for tbl_i = 1, #str do
            local length = map[str:byte(i)]

            if not length then break end

            -- this could be optional, but there are some lua files out there
            -- with unicode strings that contain bytes over 240 (4 byte length)
            -- but goes beyond the terminating quote causing the tokenizer to error
            -- with unterminated quote
            if length > 1 then
                for i2 = 1, length do
                    local b = str:byte(i + i2 - 1)
                    if not b or b <= 127 then
                        length = 1
                        break
                    end
                end
            end

            tbl[tbl_i] = str:sub(i, i + length - 1)
            i = i + length
        end

        return tbl
    end
end

function util.FetchCode(path, url)
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

function util.RemoveBOMHeader(str)
    if str:sub(1, 2) == "\xFE\xFF" then
        return str:sub(3)
    elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
        return str:sub(4)
    end
    return str
end

do
	local indent = 0
	function util.TablePrint(tbl, blacklist)
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
				io.write(("\t"):rep(indent))
				io.write(tostring(k), ":\n")
				indent = indent + 1
				util.TablePrint(v, blacklist)
				indent = indent - 1
			end
		end
	end
end

function util.CountFields(tbl, what, cb, max)
    max = max or 10

    local score = {}
    for i,v in ipairs(tbl) do
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