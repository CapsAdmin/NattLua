local jutil = require("jit.util")
local vmdef = require("jit.vmdef")
local disass = require("jit.dis_" .. jit.arch)
local symtabmt = {__index = false}
local symtab = {}
local nexitsym = 0

local function fillsymtab_tr(tr--[[#: number]], nexit--[[#: number]])
	local t = {}
	symtabmt.__index = t

	if jit.arch:sub(1, 4) == "mips" then
		t[jutil.traceexitstub(tr, 0)] = "exit"
		return
	end

	for i = 0, nexit - 1 do
		local addr = jutil.traceexitstub(tr, i)

		if addr < 0 then addr = addr + 2 ^ 32 end

		t[addr] = tostring(i)
	end

	local addr = jutil.traceexitstub(tr, nexit)

	if addr then t[addr] = "stack_check" end
end

-- Fill symbol table with trace exit stub addresses.
local function fillsymtab(tr--[[#: number]], nexit--[[#: number]])
	local t = symtab

	if nexitsym == 0 then
		local maskaddr = jit.arch == "arm" and -2
		local ircall = vmdef.ircall

		for i = 0, #ircall do
			local addr = jutil.ircalladdr(i)

			if addr ~= 0 then
				if maskaddr then addr = bit.band(addr, maskaddr) end

				if addr < 0 then addr = addr + 2 ^ 32 end

				t[addr] = ircall[i]
			end
		end
	end

	if nexitsym == 1000000 then -- Per-trace exit stubs.
		fillsymtab_tr(tr, nexit)
	elseif nexit > nexitsym then -- Shared exit stubs.
		for i = nexitsym, nexit - 1 do
			local addr = jutil.traceexitstub(i)

			if addr == nil then -- Fall back to per-trace exit stubs.
				fillsymtab_tr(tr, nexit)
				setmetatable(symtab, symtabmt)
				nexit = 1000000

				break
			end

			if addr < 0 then addr = addr + 2 ^ 32 end

			t[addr] = tostring(i)
		end

		nexitsym = nexit
	end

	return t
end

local cache = {}

local function get_mcode_stats(trace)
	local tr = trace.id

	if cache[tr] then return cache[tr] end

	local cached = {}
	cache[tr] = cached
	local mcode, addr, loop = jutil.tracemc(tr)

	if addr < 0 then addr = addr + 2 ^ 32 end

	local ctx = disass.create(mcode, addr, function(str)
		local start, stop = str:find("->lj_", nil, true)

		if start then
			local func = str:sub(start + 2):sub(1, -2)
			cached[func] = (cached[func] or 0) + 1
		end
	end)
	ctx.hexdump = 0
	ctx.symtab = fillsymtab(tr, trace.trace_info.nexit)

	if loop ~= 0 then
		symtab[addr + loop] = "LOOP"
		ctx:disass(0, loop)
		ctx:disass(loop, #mcode - loop)
		symtab[addr + loop] = nil
	else
		ctx:disass(0, #mcode)
	end

	return cached
end

return get_mcode_stats
